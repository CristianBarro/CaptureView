// Synthetic test for the frame-generation shaders.
// A textured square moves STEP px per real frame at 30 fps inside a 60 Hz tick
// (every other tick is a repeat). On a real frame the in-between image (t=0.5)
// is grabbed; the square's centre should sit halfway between prev and cur.
import QtQuick
import QtQuick.Window

Window {
    id: w
    width: 1920; height: 1080
    visible: true
    color: "black"

    readonly property int step: 24
    property real sqX: 400
    property int tick: 0
    property int curSlot: 0
    property real fgT: 1.0
    property var results: []

    Item {
        id: src
        width: 1920; height: 1080
        Rectangle {   // textured background so block matching has detail
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#203040" }
                GradientStop { position: 1; color: "#405060" }
            }
        }
        Grid {
            columns: 48
            Repeater {
                model: 48 * 27
                Rectangle { width: 40; height: 40; color: (index * 7919 % 13) < 6 ? "#2a3a4a" : "#354555" }
            }
        }
        Rectangle {
            id: sq
            x: w.sqX; y: 500; width: 120; height: 120
            color: "white"
            Rectangle { anchors.centerIn: parent; width: 40; height: 40; color: "red" }
        }
    }

    ShaderEffectSource { id: bigA; visible: false; sourceItem: src; live: false; hideSource: true; textureSize: Qt.size(1920, 1080) }
    ShaderEffectSource { id: bigB; visible: false; sourceItem: src; live: false; textureSize: Qt.size(1920, 1080) }
    ShaderEffectSource { id: smallA; visible: false; sourceItem: src; live: false; textureSize: Qt.size(480, 270); smooth: true }
    ShaderEffectSource { id: smallB; visible: false; sourceItem: src; live: false; textureSize: Qt.size(480, 270); smooth: true }

    ShaderEffect {
        id: flowFx
        width: 240; height: 135
        property variant prevS: w.curSlot === 0 ? smallB : smallA
        property variant curS: w.curSlot === 0 ? smallA : smallB
        property vector2d spx: Qt.vector2d(1.0 / 480, 1.0 / 270)
        fragmentShader: "../flow.frag.qsb"
    }
    ShaderEffectSource { id: flowSrc; visible: false; sourceItem: flowFx; hideSource: true; format: ShaderEffectSource.RGBA16F; smooth: true }

    ShaderEffect {
        id: fgOut
        width: 1920; height: 1080
        property variant prevB: w.curSlot === 0 ? bigB : bigA
        property variant curB: w.curSlot === 0 ? bigA : bigB
        property variant flow: flowSrc
        property real t: w.fgT
        property real showFlow: 0
        fragmentShader: "../interp.frag.qsb"
    }

    function snap() {
        w.curSlot = 1 - w.curSlot
        if (w.curSlot === 0) { bigA.scheduleUpdate(); smallA.scheduleUpdate() }
        else { bigB.scheduleUpdate(); smallB.scheduleUpdate() }
    }

    // white-pixel centroid along row y=560 of the grabbed output
    function centreX(img) {
        let sum = 0, n = 0
        for (let x = 0; x < 1920; x += 2) {
            const c = img.pixel ? img.pixel(x, 530) : null
            if (c && c.r > 0.9 && c.g > 0.9 && c.b > 0.9) { sum += x; n++ }
        }
        return n ? sum / n : -1
    }

    Timer {
        id: clock
        interval: 16; repeat: true; running: true
        onTriggered: {
            w.tick++
            if (w.tick > 80) { running = false; report(); return }
            if (w.tick % 2 === 0) {          // real frame
                w.sqX += w.step
                snap()
                w.fgT = 0.5
                if (w.tick > 6 && w.tick % 8 === 0) {
                    const prevC = w.sqX - w.step + 60, curC = w.sqX + 60
                    const expect = (prevC + curC) / 2
                    clock.stop()   // hold t=0.5 until the grab is done
                    fgOut.grabToImage(function (r) {
                        tester.measure(r.image, expect, prevC, curC)
                        clock.start()
                    })
                }
            } else {
                w.fgT = 1.0                   // repeated tick: show the real frame
            }
        }
    }

    function report() { tester.done() }
}
