/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15

import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kscreenlocker 1.0 as ScreenLocker

Item {
    id: root

    signal switchUserClicked()

    property alias notification: message.text
    property bool switchUserEnabled
    property bool capsLockOn

    function resetFocus() {
        password.forceActiveFocus()
    }

    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: card.implicitHeight

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + Kirigami.Units.gridUnit * 4
        radius: Kirigami.Units.gridUnit
        color: "#b8202020"
        border.color: "#40ffffff"
        border.width: 1
    }

    ColumnLayout {
        id: content
        anchors {
            fill: parent
            margins: Kirigami.Units.gridUnit * 2
        }
        spacing: Kirigami.Units.largeSpacing

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: kscreenlocker_userName
            color: "white"
            font.pixelSize: Kirigami.Units.gridUnit * 1.4
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        PlasmaComponents3.Label {
            id: message
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: "#ffb4ab"
            font.bold: true
            visible: text.length > 0
        }

        PlasmaExtras.PasswordField {
            id: password
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
            placeholderText: i18nd("kscreenlocker_greet", "Password")
            enabled: !authenticator.busy
            text: PasswordSync.password
            Keys.onEnterPressed: authenticator.startAuthenticating()
            Keys.onReturnPressed: authenticator.startAuthenticating()
            Keys.onEscapePressed: {
                password.text = ""
                password.text = Qt.binding(() => PasswordSync.password)
            }
        }

        Binding {
            target: PasswordSync
            property: "password"
            value: password.text
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: i18nd("kscreenlocker_greet", "Caps Lock is on")
            color: "white"
            visible: root.capsLockOn
        }

        PlasmaComponents3.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: "white"
            visible: authenticator.authenticatorTypes & ScreenLocker.Authenticator.Fingerprint
            text: i18nd("kscreenlocker_greet", "Use your fingerprint or enter your password")
        }

        PlasmaComponents3.Button {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5
            text: i18nd("kscreenlocker_greet", "Sign in")
            icon.name: "unlock"
            enabled: !authenticator.graceLocked
            onClicked: authenticator.startAuthenticating()
        }

        PlasmaComponents3.Button {
            Layout.alignment: Qt.AlignHCenter
            text: i18nd("kscreenlocker_greet", "Switch user")
            flat: true
            visible: root.switchUserEnabled
            onClicked: root.switchUserClicked()
        }
    }

    Connections {
        target: authenticator

        function onFailed() {
            root.notification = i18nd("kscreenlocker_greet", "Incorrect password")
        }
        function onBusyChanged() {
            if (!authenticator.busy) {
                root.notification = ""
                password.selectAll()
                root.resetFocus()
            }
        }
        function onInfoMessageChanged() {
            root.notification = Qt.binding(() => authenticator.infoMessage)
        }
        function onErrorMessageChanged() {
            root.notification = Qt.binding(() => authenticator.errorMessage)
        }
        function onPromptForSecretChanged() {
            authenticator.respond(password.text)
        }
        function onSucceeded() {
            Qt.quit()
        }
    }

    Component.onCompleted: root.resetFocus()
}
