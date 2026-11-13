import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtMultimedia
import QtCore

ApplicationWindow {
    id: win
    width: 1280
    height: 760
    visible: true
    color: "black"
    title: "CaptureView"

    palette.window: "#1a1a1e"
    palette.windowText: "#eeeeee"
    palette.base: "#111114"
    palette.text: "#eeeeee"
    palette.button: "#26262c"
    palette.buttonText: "#eeeeee"
    palette.highlight: "#2a5bd7"
    palette.highlightedText: "#ffffff"

    // ---------- persisted settings ----------
    Settings {
        id: cfg
        property string videoDev: ""
        property string audioDev: ""
        property string outDev: ""
        property string format: ""
        property bool gpu: false
        property real sharp: 0.5
        property real bright: 0.0
        property real contrast: 1.0
        property real saturation: 1.0
        property real volume: 1.0
        property bool stats: true
        property string renderer: "d3d11"
        property bool framegen: false
        property bool fgDebug: false
    }

    readonly property string activeRenderer: appControl.renderer()

    MediaDevices { id: md }

    property var vFormats: []
    property int frames: 0
    property real fps: 0
    property string camError: ""
    property bool ready: false

    function pfRank(pf) {
        const n = fmtName.name(pf)
        if (n === "YUYV") return 0   // uncompressed, best quality
        if (n === "NV12") return 1
        return 2
    }

    function fmtLabel(f) {
        return f.resolution.width + "x" + f.resolution.height + " @ " + Math.round(f.maxFrameRate)
               + " fps  (" + fmtName.name(f.pixelFormat) + ")"
    }

    function rebuildFormats() {
        const dev = cam.cameraDevice
        const fl = dev.videoFormats
        const seen = {}
        const list = []
        for (let i = 0; i < fl.length; i++) {
            const f = fl[i]
            const key = fmtLabel(f)
            if (seen[key]) continue
            seen[key] = true
            list.push(f)
        }
        list.sort(function (a, b) {
            const sa = a.resolution.width * a.resolution.height * a.maxFrameRate
            const sb = b.resolution.width * b.resolution.height * b.maxFrameRate
            if (sb !== sa) return sb - sa
            return pfRank(a.pixelFormat) - pfRank(b.pixelFormat)
        })
        vFormats = list
        fmtBox.model = list.map(fmtLabel)
        let idx = fmtBox.model.indexOf(cfg.format)
        if (idx < 0) idx = 0
        fmtBox.currentIndex = idx
        applyFormat(idx)
    }

    function applyFormat(idx) {
        if (idx < 0 || idx >= vFormats.length) return
        cam.active = false
        cam.cameraFormat = vFormats[idx]
        cam.active = true
        if (ready) cfg.format = fmtLabel(vFormats[idx])
    }

    function selectVideo(idx) {
        if (idx < 0 || idx >= md.videoInputs.length) return
        cam.active = false
        cam.cameraDevice = md.videoInputs[idx]
        if (ready) cfg.videoDev = md.videoInputs[idx].description
        rebuildFormats()
    }

    function indexByDesc(list, desc) {
        for (let i = 0; i < list.length; i++)
            if (list[i].description === desc) return i
        return -1
    }

    function toggleFullscreen() {
        win.visibility = (win.visibility === Window.FullScreen) ? Window.Windowed : Window.FullScreen
    }

    Component.onCompleted: {
        frameGen.attach(vo.videoSink)
        frameGen.setEnabled(win.fgOn)
        const vins = md.videoInputs
        vidBox.model = vins.map(d => d.description)
        let vi = indexByDesc(vins, cfg.videoDev)
        if (vi < 0) {
            // prefer anything that is not a phone/virtual cam
            vi = vins.findIndex(d => !/droidcam|obs|virtual/i.test(d.description))
            if (vi < 0) vi = 0
        }

        const ains = md.audioInputs
        audBox.model = ains.map(d => d.description)
        let ai = indexByDesc(ains, cfg.audioDev)
        if (ai < 0 && vins.length > 0) {
            // match capture-card audio by first word of the video device name (e.g. "USB2")
            const token = vins[vi].description.split(" ")[0]
            ai = ains.findIndex(d => d.description.indexOf(token) >= 0)
        }
        if (ai < 0) ai = 0

        const outs = md.audioOutputs
        outBox.model = outs.map(d => d.description)
        let oi = indexByDesc(outs, cfg.outDev)
        if (oi < 0) oi = indexByDesc(outs, md.defaultAudioOutput.description)
        if (oi < 0) oi = 0

        vidBox.currentIndex = vi
        audBox.currentIndex = ai
        outBox.currentIndex = oi
        if (ains.length > 0) ain.device = ains[ai]
        if (outs.length > 0) aout.device = outs[oi]
        selectVideo(vi)
        ready = true
    }

    // ---------- capture pipeline ----------
    Camera {
        id: cam
        active: false
        onErrorOccurred: function (error, errorString) { win.camError = errorString }
    }

    // Watchdog: no frames for 3 s -> restart the camera (device was busy / decoder failed).
    // After 3 restarts, switch to the same res+fps in another pixel format (NV12 <-> MJPEG).
    property int retries: 0
    property int idleSecs: 0
    function watchdog() {
        if (vFormats.length === 0) return
        if (win.fps > 0) { idleSecs = 0; retries = 0; camError = ""; return }
        if (++idleSecs < 3) return
        idleSecs = 0
        retries++
        if (retries > 3) {
            retries = 0
            const cur = vFormats[fmtBox.currentIndex]
            const alt = vFormats.findIndex((f, i) => i !== fmtBox.currentIndex
                && f.resolution.width === cur.resolution.width
                && f.resolution.height === cur.resolution.height
                && Math.round(f.maxFrameRate) === Math.round(cur.maxFrameRate))
            if (alt >= 0) fmtBox.currentIndex = alt
        }
        applyFormat(fmtBox.currentIndex)
    }

    CaptureSession {
        id: session
        camera: cam
        videoOutput: vo
        audioInput: AudioInput { id: ain; volume: 1.0 }
        audioOutput: AudioOutput { id: aout; volume: cfg.volume }
    }

    // ---------- video ----------
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: (win.visibility === Window.FullScreen && !panel.visible) ? Qt.BlankCursor : Qt.ArrowCursor
        onDoubleClicked: toggleFullscreen()
    }

    Item {
        id: frameBox
        readonly property real ar: (cam.cameraFormat.resolution.width > 0)
                                   ? cam.cameraFormat.resolution.width / cam.cameraFormat.resolution.height
                                   : 16 / 9
        width: Math.min(parent.width, parent.height * ar)
        height: width / ar
        anchors.centerIn: parent

        readonly property size nat: cam.cameraFormat.resolution.width > 0
                                    ? cam.cameraFormat.resolution : Qt.size(1920, 1080)

        VideoOutput {
            id: vo
            anchors.fill: parent
            fillMode: VideoOutput.Stretch

            layer.enabled: win.gpuOn && !win.fgOn
            layer.smooth: true
            layer.effect: casFx
        }

        // ---- frame generation ----
        // Two slots (A/B) of snapshots of the video: full-res for the output,
        // 1/4-res for motion estimation. On each new unique frame the older
        // slot is overwritten, so the pair is always (prev, cur).
        ShaderEffectSource { id: bigA; visible: false; sourceItem: vo; live: false; hideSource: win.fgOn; textureSize: frameBox.nat; smooth: true }
        ShaderEffectSource { id: bigB; visible: false; sourceItem: vo; live: false; textureSize: frameBox.nat; smooth: true }
        ShaderEffectSource { id: smallA; visible: false; sourceItem: vo; live: false; textureSize: Qt.size(480, 270); smooth: true }
        ShaderEffectSource { id: smallB; visible: false; sourceItem: vo; live: false; textureSize: Qt.size(480, 270); smooth: true }

        ShaderEffect {
            id: flowFx
            width: 240
            height: 135
            visible: win.fgOn
            property variant prevS: win.curSlot === 0 ? smallB : smallA
            property variant curS: win.curSlot === 0 ? smallA : smallB
            property vector2d spx: Qt.vector2d(1.0 / 480, 1.0 / 270)
            fragmentShader: "flow.frag.qsb"
        }
        ShaderEffectSource {
            id: flowSrc
            visible: false
            sourceItem: flowFx
            hideSource: true
            format: ShaderEffectSource.RGBA16F
            smooth: true
        }

        ShaderEffect {
            id: fgOut
            anchors.fill: parent
            visible: win.fgOn
            property variant prevB: win.curSlot === 0 ? bigB : bigA
            property variant curB: win.curSlot === 0 ? bigA : bigB
            property variant flow: flowSrc
            property real t: win.fgT
            property real showFlow: cfg.fgDebug ? 1.0 : 0.0
            fragmentShader: "interp.frag.qsb"

            layer.enabled: win.gpuOn
            layer.smooth: true
            layer.effect: casFx
        }
    }

    Component {
        id: casFx
        ShaderEffect {
            property vector2d px: Qt.vector2d(1.0 / Math.max(1, width), 1.0 / Math.max(1, height))
            property real sharp: cfg.sharp
            property real br: cfg.bright
            property real ct: cfg.contrast
            property real sat: cfg.saturation
            fragmentShader: "cas.frag.qsb"
        }
    }

    readonly property bool gpuOn: cfg.gpu || Qt.application.arguments.indexOf("--gpu") >= 0
    readonly property bool fgOn: cfg.framegen || Qt.application.arguments.indexOf("--fg") >= 0
    property int curSlot: 0
    property real fgT: 1.0
    property bool fgRepeat: false
    property int genFrames: 0
    property int genFps: 0

    onFgOnChanged: frameGen.setEnabled(fgOn)

    Connections {
        target: frameGen
        function onFrameInfo(unique, repeatMode) {
            if (!win.fgOn) return
            win.fgRepeat = repeatMode
            if (unique) {
                win.curSlot = 1 - win.curSlot
                if (win.curSlot === 0) { bigA.scheduleUpdate(); smallA.scheduleUpdate() }
                else { bigB.scheduleUpdate(); smallB.scheduleUpdate() }
                // repeated frames around -> show the in-between frame now,
                // the real one on the next (repeated) tick
                win.fgT = repeatMode ? 0.5 : 1.0
                if (repeatMode) win.genFrames++
            } else {
                win.fgT = 1.0
            }
        }
    }

    Connections {
        target: vo.videoSink
        function onVideoFrameChanged() { win.frames++ }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: { win.fps = win.frames; win.frames = 0; win.genFps = win.genFrames; win.genFrames = 0; win.watchdog() }
    }

    // --restarttest: exercise the restart button path (build check)
    Timer {
        interval: 4000
        running: Qt.application.arguments.indexOf("--restarttest") >= 0
        onTriggered: appControl.restart()
    }

    // --selftest: log what is running, then quit (used by the build check)
    Timer {
        interval: 12000
        running: Qt.application.arguments.indexOf("--selftest") >= 0
        onTriggered: {
            selftestLog.write("SELFTEST video=" + cam.cameraDevice.description
                        + " format=" + fmtLabel(cam.cameraFormat)
                        + " fps=" + win.fps + " gpu=" + win.gpuOn + " fg=" + win.fgOn + " dup=" + frameGen.dupRatio.toFixed(2) + " gen=" + win.genFps
                        + " audioIn=" + ain.device.description
                        + " audioOut=" + aout.device.description
                        + " renderer=" + win.activeRenderer + " err=" + win.camError)
            Qt.quit()
        }
    }

    // ---------- stats ----------
    Rectangle {
        visible: cfg.stats
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
        color: "#99000000"
        radius: 6
        width: statsText.implicitWidth + 20
        height: statsText.implicitHeight + 12
        Text {
            id: statsText
            anchors.centerIn: parent
            color: "#eeeeee"
            font.family: "Consolas"
            font.pixelSize: 13
            text: cam.cameraFormat.resolution.width + "x" + cam.cameraFormat.resolution.height
                  + "  " + win.fps.toFixed(0) + " / " + Math.round(cam.cameraFormat.maxFrameRate) + " fps"
                  + (win.gpuOn ? "  [GPU]" : "  [Direto]")
                  + (win.fgOn ? "
Frame gen: " + (win.fgRepeat ? "ativo, " + win.genFps + " quadros gerados/s" : "sem quadros repetidos (já é 60)") + "  repetidos " + Math.round(frameGen.dupRatio * 100) + "%" : "")
                  + "  " + win.activeRenderer.toUpperCase()
                  + (win.camError ? "\nERRO: " + win.camError : "")
        }
    }

    // ---------- control panel ----------
    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 12
        width: 330
        height: col.implicitHeight + 24
        radius: 10
        color: "#e6141418"
        border.color: "#333"

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            Label { text: "CaptureView"; font.pixelSize: 16; font.bold: true }

            Label { text: "Vídeo (placa de captura)"; color: "#aaa" }
            ComboBox { id: vidBox; Layout.fillWidth: true; onActivated: idx => { selectVideo(idx) } }

            Label { text: "Resolução / FPS"; color: "#aaa" }
            ComboBox { id: fmtBox; Layout.fillWidth: true; onActivated: idx => { applyFormat(idx) } }

            Label { text: "Áudio da placa"; color: "#aaa" }
            ComboBox {
                id: audBox; Layout.fillWidth: true
                onActivated: idx => { ain.device = md.audioInputs[idx]; cfg.audioDev = md.audioInputs[idx].description }
            }

            Label { text: "Saída de áudio"; color: "#aaa" }
            ComboBox {
                id: outBox; Layout.fillWidth: true
                onActivated: idx => { aout.device = md.audioOutputs[idx]; cfg.outDev = md.audioOutputs[idx].description }
            }

            Label { text: "Volume " + Math.round(cfg.volume * 100) + "%"; color: "#aaa" }
            Slider { Layout.fillWidth: true; from: 0; to: 1; value: cfg.volume; onMoved: cfg.volume = value }

            CheckBox { text: "Modo GPU (nitidez + cor)"; checked: cfg.gpu; onToggled: cfg.gpu = checked }
            CheckBox { text: "Frame gen (30 → 60, +1 quadro de atraso)"; checked: cfg.framegen; onToggled: cfg.framegen = checked }
            CheckBox { visible: cfg.framegen; text: "Ver vetores de movimento (debug)"; checked: cfg.fgDebug; onToggled: cfg.fgDebug = checked }

            ColumnLayout {
                visible: cfg.gpu
                Layout.fillWidth: true
                spacing: 2
                Label { text: "Nitidez (CAS) " + cfg.sharp.toFixed(2); color: "#aaa" }
                Slider { Layout.fillWidth: true; from: 0; to: 1; value: cfg.sharp; onMoved: cfg.sharp = value }
                Label { text: "Brilho " + cfg.bright.toFixed(2); color: "#aaa" }
                Slider { Layout.fillWidth: true; from: -0.2; to: 0.2; value: cfg.bright; onMoved: cfg.bright = value }
                Label { text: "Contraste " + cfg.contrast.toFixed(2); color: "#aaa" }
                Slider { Layout.fillWidth: true; from: 0.7; to: 1.4; value: cfg.contrast; onMoved: cfg.contrast = value }
                Label { text: "Saturação " + cfg.saturation.toFixed(2); color: "#aaa" }
                Slider { Layout.fillWidth: true; from: 0; to: 2; value: cfg.saturation; onMoved: cfg.saturation = value }
                Button {
                    text: "Resetar cor"
                    onClicked: { cfg.bright = 0; cfg.contrast = 1; cfg.saturation = 1 }
                }
            }

            CheckBox { text: "Mostrar FPS"; checked: cfg.stats; onToggled: cfg.stats = checked }

            Label { text: "Renderizador"; color: "#aaa" }
            ComboBox {
                id: rendBox
                Layout.fillWidth: true
                model: ["D3D11 (padrão)", "D3D12 (ReShade / DLSS5)"]
                currentIndex: cfg.renderer === "d3d12" ? 1 : 0
                onActivated: idx => cfg.renderer = (idx === 1 ? "d3d12" : "d3d11")
            }
            Button {
                visible: cfg.renderer !== win.activeRenderer
                Layout.fillWidth: true
                text: "Reiniciar para aplicar " + cfg.renderer.toUpperCase()
                onClicked: { cfg.sync(); appControl.restart() }
            }

            Label {
                text: "F / duplo clique = tela cheia · H = painel · S = FPS · Esc = sair da tela cheia"
                color: "#777"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
        }
    }

    Shortcut { sequence: "F"; context: Qt.ApplicationShortcut; onActivated: toggleFullscreen() }
    Shortcut { sequence: "F11"; context: Qt.ApplicationShortcut; onActivated: toggleFullscreen() }
    Shortcut { sequence: "H"; context: Qt.ApplicationShortcut; onActivated: panel.visible = !panel.visible }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; onActivated: cfg.stats = !cfg.stats }
    Shortcut { sequence: "Esc"; context: Qt.ApplicationShortcut; onActivated: win.visibility = Window.Windowed }
}
