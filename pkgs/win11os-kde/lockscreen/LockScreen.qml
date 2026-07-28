/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick 2.15
import org.kde.plasma.private.sessions 2.0

Item {
    id: lockScreen

    property alias capsLockOn: unlockUI.capsLockOn
    property bool locked: false

    signal unlockRequested()

    Image {
        anchors.fill: parent
        source: "background.jpeg"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: "#40000000"
    }

    SessionManagement {
        id: sessionManagement
    }

    Greeter {
        id: unlockUI
        anchors.centerIn: parent
        visible: lockScreen.locked
        switchUserEnabled: sessionManagement.canSwitchUser
        onSwitchUserClicked: sessionManagement.switchUser()
    }
}
