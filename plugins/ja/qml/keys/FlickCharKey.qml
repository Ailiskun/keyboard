/*
 * Copyright 2015 Canonical Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4

import MaliitKeyboard 2.0

import "key_constants.js" as UI

Item {
    id: key

    property int padding: 0

    width: leftSide || rightSide ? panel.keyWidth * 2 : panel.keyWidth
    height: panel.keyHeight

    /* to be set in keyboard layouts */
    property string label: "";
    property var leaves: ["", "", "", "", ""];
    property int index: keyFlickArea.index;
    property bool highlight: false;

    property string action
    property bool noMagnifier: false
    property bool skipAutoCaps: false
    property bool switchBackFromSymbols: false

    property bool leftSide: false
    property bool rightSide: false

    property double rowMargin: fullScreenItem.tablet ? units.gu(UI.tabletRowMargin)
                                                     : (fullScreenItem.landscape ? units.dp(UI.phoneRowMarginLandscape)
                                                                                 : units.dp(UI.phoneRowMarginPortrait))
    property double keyMargin: fullScreenItem.tablet ? units.gu(UI.tabletKeyMargins)
                                                     : units.gu(UI.phoneKeyMargins)

    // These properties are used by autopilot to determine the visible
    // portion of the key to press
    readonly property double leftOffset: buttonRect.anchors.leftMargin
    readonly property double rightOffset: buttonRect.anchors.rightMargin

    /* design */
    property string normalColor: UI.charKeyColor
    property string pressedColor: UI.charKeyPressedColor
    property int fontSize: (fullScreenItem.landscape ? (height / 2) : (height / 2.8));

    /// annotation shows a small label in the upper right corner
    // if the annotiation property is set, it will be used. If not, the first position in extended[] list or extendedShifted[] list will
    // be used, depending on the state. If no extended/extendedShifted arrays exist, no annotation is shown
    property string annotation: ""

    /*! indicates if te key is currently pressed/down*/
    property alias currentlyPressed: keyFlickArea.pressed

    property string oskState: panel.activeKeypadState

    // Allow action keys to override the standard key behaviour
    property bool overridePressArea: false

    signal pressed()
    signal released()

    // Make it possible for the visible area of the key to differ from the
    // actual key size. This allows us to extend the touch area of the bottom
    // row of keys all the way to the bottom of the keyboard, whilst
    // maintaining the same visual appearance.
    Item {
        anchors.top: parent.top
        height: panel.keyHeight
        width: parent.width

        Rectangle {
            id: buttonRect
            color: key.currentlyPressed || key.highlight ? pressedColor : normalColor
            anchors.fill: parent
            anchors.leftMargin: key.leftSide ? (parent.width - panel.keyWidth) + key.keyMargin : key.keyMargin
            anchors.rightMargin: key.rightSide ? (parent.width - panel.keyWidth) + key.keyMargin : key.keyMargin
            anchors.bottomMargin: key.rowMargin
            radius: units.dp(4)

            /// label of the key
            //  the label is also the value subitted to the app

            Column {
                spacing: units.gu( UI.annotationMargins )
                anchors.centerIn: parent

                Text {
                    id: keyLabel
                    text: label
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: UI.fontFamily
                    font.pixelSize: fontSize
                    font.weight: Font.Light
                    color: UI.fontColor
                    textFormat: Text.StyledText
                }

                Text {
                    id: annotationLabel
                    text: annotation

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: units.gu( UI.annotationMargins )

                    font.family: UI.annotationFont
                    font.pixelSize: fullScreenItem.tablet ? units.dp(UI.tabletAnnotationFontSize) : units.dp(UI.phoneAnnotationFontSize)
                    font.weight: Font.Light
                    color: UI.annotationFontColor
                    visible: annotation != ""
                }
            }
        }

        FlickPop {
            anchors.horizontalCenter: buttonRect.horizontalCenter
            anchors.bottom: buttonRect.top
            anchors.bottomMargin: key.height * 0.5
            width: units.gu((UI.fontSize + UI.flickMargin) * 3)
            height: units.gu((UI.fontSize + UI.flickMargin) * 3)
            chars: leaves
            index: keyFlickArea.index
            visible: key.currentlyPressed && chars.length > 1
        }
    }

    FlickArea {
        id: keyFlickArea
        anchors.fill: key

        onReleased: {
            if (overridePressArea) {
                key.released();
                return;
            }

            event_handler.onKeyReleased(leaves[index], action);
        }

        onPressed: {
            if (overridePressArea) {
                key.pressed();
                return;
            }

            Feedback.keyPressed();

            event_handler.onKeyPressed(leaves[index], action);
        }
    }

    Connections {
        target: swipeArea.drag
        onActiveChanged: {
            if (swipeArea.drag.active)
                keyFlickArea.cancelPress();
        }
    }
}
