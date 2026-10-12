pragma Singleton
pragma ComponentBehavior: Bound

// Took many bits from https://github.com/caelestia-dots/shell (GPLv3)

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services.network

/**
 * Network service with nmcli.
 */
Singleton {
    id: root

    property bool wifi: true
    property bool ethernet: false

    property bool wifiEnabled: false
    property bool wifiScanning: false
    property bool wifiConnecting: connectProc.running || passwordConnectProc.running
    property WifiAccessPoint wifiConnectTarget
    readonly property list<WifiAccessPoint> wifiNetworks: []
    readonly property WifiAccessPoint active: wifiNetworks.find(n => n.active) ?? null
    readonly property list<var> friendlyWifiNetworks: [...wifiNetworks].sort((a, b) => {
        if (a.active && !b.active)
            return -1;
        if (!a.active && b.active)
            return 1;
        return b.strength - a.strength;
    })
    property string wifiStatus: "disconnected"
    property var savedSsids: [] // Wi-Fi networks this machine has a saved profile for

    function refreshList(): void {
        getNetworks.running = true;
    }
    function quietRescan(): void { // ask for a fresh scan without showing "looking for networks"
        quietRescanProc.running = true;
    }
    function forgetWifiNetwork(ssid: string): void {
        forgetProc.exec(["nmcli", "connection", "delete", "id", ssid]);
    }

    property string networkName: ""
    property int networkStrength
    property string materialSymbol: root.ethernet
        ? "lan"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? (
                (root.active?.strength ?? 0) > 83 ? "signal_wifi_4_bar" :
                (root.active?.strength ?? 0) > 67 ? "network_wifi" :
                (root.active?.strength ?? 0) > 50 ? "network_wifi_3_bar" :
                (root.active?.strength ?? 0) > 33 ? "network_wifi_2_bar" :
                (root.active?.strength ?? 0) > 17 ? "network_wifi_1_bar" :
                "signal_wifi_0_bar"
            )
            : (root.wifiStatus === "connecting")
                ? "signal_wifi_statusbar_not_connected"
                : (root.wifiStatus === "disconnected")
                    ? "wifi_find"
                    : (root.wifiStatus === "disabled")
                        ? "signal_wifi_off"
                        : "signal_wifi_bad"

    // Control
    function enableWifi(enabled = true): void {
        const cmd = enabled ? "on" : "off";
        enableWifiProc.exec(["nmcli", "radio", "wifi", cmd]);
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    function rescanWifi(): void {
        wifiScanning = true;
        rescanProcess.running = true;
    }

    // If an attempt fails, go back to the network that was in use before it.
    readonly property string fallbackScript: 'rc=$?; if [ $rc -ne 0 ] && [ -n "$PREV" ] && [ "$PREV" != "$SSID" ]; then nmcli connection up id "$PREV" >/dev/null 2>&1; fi; exit $rc'

    function connectToWifiNetwork(accessPoint: WifiAccessPoint): void {
        accessPoint.error = "";
        const saved = root.savedSsids.includes(accessPoint.ssid);
        // A protected network we have no password for: ask first. Trying to join without one
        // would only drop the current connection and then fail.
        if (accessPoint.isSecure && !saved) {
            accessPoint.askingPassword = true;
            return;
        }
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        connectProc.exec({
            "environment": { "SSID": accessPoint.ssid, "PREV": root.active?.ssid ?? "", "SAVED": saved ? "1" : "", "LANG": "C", "LC_ALL": "C" },
            "command": ["bash", "-c",
                'if [ -n "$SAVED" ]; then nmcli connection up id "$SSID"; else nmcli device wifi connect "$SSID"; fi; ' + root.fallbackScript]
        })
    }

    // Connect with a password typed by the user. Works for a network that has never been joined
    // (creates its profile) and for a saved one whose password changed (updates the profile in
    // place, so its other settings are kept).
    function connectWithPassword(accessPoint: WifiAccessPoint, password: string): void {
        accessPoint.error = "";
        root.wifiConnectTarget = accessPoint;
        passwordConnectProc.exec({
            "environment": { "PASSWORD": password, "SSID": accessPoint.ssid, "PREV": root.active?.ssid ?? "",
                             "SAVED": root.savedSsids.includes(accessPoint.ssid) ? "1" : "", "LANG": "C", "LC_ALL": "C" },
            "command": ["bash", "-c",
                'if [ -n "$SAVED" ]; then nmcli connection modify "$SSID" wifi-sec.psk "$PASSWORD" && nmcli connection up id "$SSID"; ' +
                // a failed first join leaves a profile with the wrong password behind: remove it
                'else nmcli device wifi connect "$SSID" password "$PASSWORD" || { rc=$?; nmcli connection delete id "$SSID" >/dev/null 2>&1; (exit $rc); }; fi; ' +
                root.fallbackScript]
        })
    }

    function disconnectWifiNetwork(): void {
        if (active) disconnectProc.exec(["nmcli", "connection", "down", active.ssid]);
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]) // From some StackExchange thread, seems to work
    }

    function changePassword(network: WifiAccessPoint, password: string, username = ""): void {
        // TODO: enterprise wifi with username
        network.askingPassword = false;
        changePasswordProc.exec({
            "environment": {
                "PASSWORD": password,
                "SSID": network.ssid
            },
            "command": ["bash", "-c", 'nmcli connection modify "$SSID" wifi-sec.psk "$PASSWORD"']
        })
    }

    Process {
        id: enableWifiProc
    }

    Process {
        id: quietRescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        onExited: getNetworks.running = true
    }
    Process {
        id: forgetProc
        onExited: {
            savedProc.running = true
            getNetworks.running = true
        }
    }
    Process {
        id: savedProc
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        environment: ({ LANG: "C", LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                root.savedSsids = text.split("\n").filter(l => l.endsWith(":802-11-wireless"))
                    .map(l => l.slice(0, l.lastIndexOf(":")).replace(/\\:/g, ":"))
            }
        }
    }

    Process {
        id: connectProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: SplitParser {
            onRead: line => {
                // print(line)
                getNetworks.running = true
            }
        }
        stderr: SplitParser {
            onRead: line => {
                // print("err:", line)
                if (line.includes("Secrets were required") && root.wifiConnectTarget?.isSecure) {
                    root.wifiConnectTarget.askingPassword = true
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            const target = root.wifiConnectTarget
            if (target) {
                // A protected network that fails here needs its password; an open one simply failed.
                if (exitCode !== 0 && target.isSecure) target.askingPassword = true
                else target.askingPassword = false
                target.error = (exitCode !== 0 && !target.isSecure) ? "Couldn't connect" : ""
                if (!target.isSecure) target.askingPassword = false
            }
            root.wifiConnectTarget = null
            getNetworks.running = true
        }
    }

    Process {
        id: passwordConnectProc
        stderr: StdioCollector { id: passwordConnectErr }
        onExited: (exitCode, exitStatus) => {
            const target = root.wifiConnectTarget
            if (target) {
                if (exitCode === 0) {
                    target.askingPassword = false
                    target.error = ""
                } else {
                    target.askingPassword = true
                    const msg = passwordConnectErr.text
                    target.error = /Secrets were required|psk|password|802-1x|4-way/i.test(msg) ? "Wrong password" : "Couldn't connect"
                }
            }
            root.wifiConnectTarget = null
            getNetworks.running = true
        }
    }

    Process {
        id: disconnectProc
        stdout: SplitParser {
            onRead: getNetworks.running = true
        }
    }

    Process {
        id: changePasswordProc
        onExited: { // Re-attempt connection after changing password
            connectProc.running = false
            connectProc.running = true
        }
    }

    Process {
        id: rescanProcess
        command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
        stdout: SplitParser {
            onRead: {
                wifiScanning = false;
                getNetworks.running = true;
            }
        }
    }

    // Status update
    function update() {
        updateConnectionType.startCheck();
        wifiStatusProcess.running = true
        updateNetworkName.running = true;
        updateNetworkStrength.running = true;
        getNetworks.running = true; // the list (and which network is active) follows every change too
        savedProc.running = true;
    }

    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: root.update()
        }
    }

    Process {
        id: updateConnectionType
        property string buffer
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE d status && nmcli -t -f CONNECTIVITY g"]
        running: true
        function startCheck() {
            buffer = "";
            updateConnectionType.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                updateConnectionType.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const lines = updateConnectionType.buffer.trim().split('\n');
            const connectivity = lines.pop() // none, limited, full
            let hasEthernet = false;
            let hasWifi = false;
            let wifiStatus = "disconnected";
            lines.forEach(line => {
                if (line.includes("ethernet") && line.includes("connected"))
                    hasEthernet = true;
                else if (line.includes("wifi:")) {
                    if (line.includes("disconnected")) {
                        wifiStatus = "disconnected"
                    }
                    else if (line.includes("connected")) {
                        hasWifi = true;
                        wifiStatus = "connected"

                        if (connectivity === "limited") {
                            hasWifi = false;
                            wifiStatus = "limited"
                        }
                    }
                    else if (line.includes("connecting")) {
                        wifiStatus = "connecting"
                    }
                    else if (line.includes("unavailable")) {
                        wifiStatus = "disabled"
                    }
                }
            });
            root.wifiStatus = wifiStatus;
            root.ethernet = hasEthernet;
            root.wifi = hasWifi;
        }
    }

    Process {
        id: updateNetworkName
        command: ["sh", "-c", "nmcli -t -f NAME c show --active | head -1"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.networkName = data;
            }
        }
    }

    Process {
        id: updateNetworkStrength
        running: true
        command: ["sh", "-c", "nmcli -f IN-USE,SIGNAL,SSID device wifi | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        stdout: SplitParser {
            onRead: data => {
                root.networkStrength = parseInt(data);
            }
        }
    }

    Process {
        id: wifiStatusProcess
        command: ["nmcli", "radio", "wifi"]
        Component.onCompleted: running = true
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";
            }
        }
    }

    Process {
        id: getNetworks
        running: true
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const rep = new RegExp("\\\\:", "g");
                const rep2 = new RegExp(PLACEHOLDER, "g");

                const allNetworks = text.trim().split("\n").map(n => {
                    const net = n.replace(rep, PLACEHOLDER).split(":");
                    return {
                        active: net[0] === "yes",
                        strength: parseInt(net[1]),
                        frequency: parseInt(net[2]),
                        ssid: net[3],
                        bssid: net[4]?.replace(rep2, ":") ?? "",
                        security: net[5] || ""
                    };
                }).filter(n => n.ssid && n.ssid.length > 0);

                // Group networks by SSID and prioritize connected ones
                const networkMap = new Map();
                for (const network of allNetworks) {
                    const existing = networkMap.get(network.ssid);
                    if (!existing) {
                        networkMap.set(network.ssid, network);
                    } else {
                        // Prioritize active/connected networks
                        if (network.active && !existing.active) {
                            networkMap.set(network.ssid, network);
                        } else if (!network.active && !existing.active) {
                            // If both are inactive, keep the one with better signal
                            if (network.strength > existing.strength) {
                                networkMap.set(network.ssid, network);
                            }
                        }
                        // If existing is active and new is not, keep existing
                    }
                }

                const wifiNetworks = Array.from(networkMap.values());

                const rNetworks = root.wifiNetworks;

                const destroyed = rNetworks.filter(rn => !wifiNetworks.find(n => n.ssid === rn.ssid));
                for (const network of destroyed)
                    rNetworks.splice(rNetworks.indexOf(network), 1).forEach(n => n.destroy());

                for (const network of wifiNetworks) {
                    const match = rNetworks.find(n => n.ssid === network.ssid);
                    if (match) {
                        match.lastIpcObject = network;
                    } else {
                        rNetworks.push(apComp.createObject(root, {
                            lastIpcObject: network
                        }));
                    }
                }
            }
        }
    }

    Component {
        id: apComp

        WifiAccessPoint {}
    }
}
