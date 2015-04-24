/*
 * Copyright 2013 Canonical Ltd.
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

import QtQuick 2.0
import QtMultimedia 5.0
import Ubuntu.Components 0.1
import Ubuntu.Components.Popups 0.1

import "key_constants.js" as UI

Item {
    id: key

    property int padding: 0

    width: leftSide || rightSide ? panel.keyWidth * 2 : panel.keyWidth
    height: panel.keyHeight

    /* to be set in keyboard layouts */
    property string label: ""
    property string shifted: ""
    property var extended; // list of extended keys
    property var extendedShifted; // list of extended keys in shifted state
    property var currentExtendedKey; // The currently highlighted extended key
    property bool highlight: false;

    property alias valueToSubmit: keyLabel.text

    property alias acceptDoubleClick: keyMouseArea.acceptDoubleClick

    property string action
    property bool noMagnifier: false
    property bool skipAutoCaps: false
    property bool switchBackFromSymbols: false

    property bool leftSide: false
    property bool rightSide: false

    // These properties are used by autopilot to determine the visible 
    // portion of the key to press
    readonly property double leftOffset: buttonImage.anchors.leftMargin
    readonly property double rightOffset: buttonImage.anchors.rightMargin

    /* design */
    property string imgNormal: UI.imageCharKey
    property string imgPressed: UI.imageCharKeyPressed
    // fontSize can be overwritten when using the component, e.g. SymbolShiftKey uses smaller fontSize
    property int fontSize: units.gu( UI.fontSize );

    /// annotation shows a small label in the upper right corner
    // if the annotiation property is set, it will be used. If not, the first position in extended[] list or extendedShifted[] list will
    // be used, depending on the state. If no extended/extendedShifted arrays exist, no annotation is shown
    property string annotation: ""

    /*! indicates if te key is currently pressed/down*/
    property alias currentlyPressed: keyMouseArea.pressed

    /* internal */
    property string __annotationLabelNormal
    property string __annotationLabelShifted

    /**
     * this property specifies if the key can submit its value or not (e.g. when the popover is shown, it does not commit its value)
     */

    property bool extendedKeysShown: extendedKeysSelector.enabled

    /*
     * label changes when keyboard is in shifted mode
     * extended keys change as well when shifting keyboard, typically lower-uppercase: ê vs Ê
     */

    property string oskState: panel.activeKeypadState
    property var activeExtendedModel: (panel.activeKeypadState === "NORMAL") ? extended : extendedShifted

    // Allow action keys to override the standard key behaviour
    property bool overridePressArea: false

    // Don't detect swipe changes until the swipeTimer has expired to prevent
    // accidentally selecting something other than the default extended key
    property bool swipeReady: false

    signal pressed()
    signal released()
    signal pressAndHold()
    signal doubleClicked()

    Component.onCompleted: {
        if (annotation) {
            __annotationLabelNormal = annotation
            __annotationLabelShifted = annotation
        } else {
            if (extended)
                __annotationLabelNormal = extended[0]
            if (extendedShifted)
                __annotationLabelShifted = extendedShifted[0]
        }
    }

    // Make it possible for the visible area of the key to differ from the
    // actual key size. This allows us to extend the touch area of the bottom
    // row of keys all the way to the bottom of the keyboard, whilst 
    // maintaining the same visual appearance.
    Item {
        anchors.top: parent.top
        height: panel.keyHeight
        width: parent.width

        BorderImage {
            id: buttonImage
            anchors.fill: parent
            anchors.leftMargin: key.leftSide ? (parent.width - panel.keyWidth) + units.dp(UI.keyMargins) :  units.dp(UI.keyMargins)
            anchors.rightMargin: key.rightSide ? (parent.width - panel.keyWidth) + units.dp(UI.keyMargins) :  units.dp(UI.keyMargins)
            anchors.bottomMargin: orientationHelper.orientationAngle == 0 || orientationHelper.orientationAngle == 180 ? units.gu(UI.row_margin) : units.dp( UI.keyMargins ) * 2;
            source: key.imgNormal

            BorderImage {
                anchors.fill: parent
                visible: key.currentlyPressed || key.highlight
                source: key.imgPressed    
            }

            /// label of the key
            //  the label is also the value subitted to the app
        
            Text {
                id: keyLabel
                text: (panel.activeKeypadState === "NORMAL") ? label : shifted;
                font.family: UI.fontFamily
                font.pixelSize: fontSize
                font.bold: UI.fontBold
                color: UI.fontColor
                anchors.right: parent.right
                anchors.left: parent.left
                anchors.leftMargin: units.gu(0.2)
                anchors.rightMargin: units.gu(0.2)
                anchors.verticalCenter: parent.verticalCenter 
                anchors.verticalCenterOffset: -units.gu(0.15)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        
            /// shows an annotation
            // used e.g. for indicating the existence of extended keys
        
            Text {
                id: annotationLabel
                text: (panel.activeKeypadState != "NORMAL") ? __annotationLabelShifted : __annotationLabelNormal
        
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: units.gu(UI.annotationTopMargin)
                anchors.rightMargin: units.gu(UI.annotationRightMargin)
        
                font.pixelSize: units.gu( UI.annotationFontSize )
                font.bold: false
                color: UI.annotationFontColor
            }

        }
    }

    PressArea {
        id: keyMouseArea
        anchors.fill: parent

        onPressAndHold: {
            if (overridePressArea) {
                key.pressAndHold();
                return;
            }
            if (activeExtendedModel != undefined) {
                if (maliit_input_method.useHapticFeedback)
                    pressEffect.start();

                swipeReady = false;
                swipeTimer.restart();
                magnifier.shown = false
                extendedKeysSelector.enabled = true
                extendedKeysSelector.extendedKeysModel = activeExtendedModel
                extendedKeysSelector.currentlyAssignedKey = key
                var extendedKeys = extendedKeysSelector.keys;
                var middleKey = extendedKeys.length > 1 ? Math.floor(extendedKeys.length / 2) - 1 : 0;
                extendedKeys[middleKey].highlight = true;
                currentExtendedKey = extendedKeys[middleKey];
            }
        }

        onMouseXChanged: {
            evaluateSelectorSwipe();
        }

        onMouseYChanged: {
            evaluateSelectorSwipe();
        }

        onReleased: {
            if (overridePressArea) {
                key.released();
                return;
            }
            if (extendedKeysShown) {
                if (currentExtendedKey) {
                    currentExtendedKey.commit();
                    currentExtendedKey = null;
                } else {
                    extendedKeysSelector.closePopover(); 
                }
            } else if(!swipedOut) {
                // Read this prior to altering autocaps
                var keyToSend = valueToSubmit; 
                if (magnifier.currentlyAssignedKey == key) {
                    magnifier.shown = false;
                }

                if (panel.autoCapsTriggered && action != "backspace") {
                    panel.autoCapsTriggered = false;
                }
                else if (!skipAutoCaps) {
                    if (panel.activeKeypadState === "SHIFTED" && panel.state === "CHARACTERS")
                        panel.activeKeypadState = "NORMAL";
                }
                if (switchBackFromSymbols && panel.state === "SYMBOLS") {
                    panel.state = "CHARACTERS";
                }
                event_handler.onKeyReleased(keyToSend, action);
            } else if (action == "backspace") {
                // Send release from backspace if we're swiped out since
                // backspace activates on press and deactivates on release
                // to allow for repeated backspaces, unlike normal keys
                // which activate on release.
                event_handler.onKeyReleased(valueToSubmit, action);
            }
        }

        onSwipedOutChanged: {
            if(swipedOut && magnifier.currentlyAssignedKey == key) {
                magnifier.shown = false;
            }
        }

        onPressed: {
            if (overridePressArea) {
                key.pressed();
                return;
            }
            magnifier.currentlyAssignedKey = key
            magnifier.shown = !noMagnifier

            if (maliit_input_method.useAudioFeedback)
                audioFeedback.play();
            
            if (maliit_input_method.useHapticFeedback)
                 pressEffect.start();

            // Quick workaround to fix initial autocaps - not beautiful, but works
            if(action != "backspace") {
                panel.autoCapsTriggered = false;
            }
            event_handler.onKeyPressed(valueToSubmit, action);
        }

        onDoubleClicked: {
            if (overridePressArea) {
                key.doubleClicked();
                return;
            }
        }

        // Determine which extended key we're underneath when swiping,
        // highlight it and set it as the currentExtendedKey (to be committed
        // when press is released)
        function evaluateSelectorSwipe() {
            if (extendedKeysSelector.enabled && swipeReady) {
                var extendedKeys = extendedKeysSelector.keys;
                currentExtendedKey = null;
                var keyMapping = extendedKeysSelector.mapToItem(key, extendedKeysSelector.rowX, extendedKeysSelector.rowY);
                var mx = mouseX - keyMapping.x;
                var my = mouseY - keyMapping.y;
                for(var i = 0; i < extendedKeys.length; i++) {
                    var posX = extendedKeys[i].x;
                    var posY = extendedKeys[i].y;
                    if(mx > posX && mx < (posX + extendedKeys[i].width)
                       && my > posY && my < (posY + extendedKeys[i].height * 2.5)) {
                        if(!extendedKeys[i].highlight && maliit_input_method.useHapticFeedback) {
                            pressEffect.start();
                        }
                        extendedKeys[i].highlight = true;
                        currentExtendedKey = extendedKeys[i];
                    } else if('highlight' in extendedKeys[i]) {
                        extendedKeys[i].highlight = false;
                    }
                }
            }
        }
    }

    Timer {
        id: swipeTimer
        interval: 750
        onTriggered: {
            swipeReady = true;
            keyMouseArea.evaluateSelectorSwipe();
        }
    }

    Connections {
        target: swipeArea.drag
        onActiveChanged: {
            if (swipeArea.drag.active)
                keyMouseArea.cancelPress();
        }
    }
}
