/*
    Copyright © 2022, Inochi2D Project
    Copyright © 2024, nijigenerate Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module nijiexpose.plugins.api.ui;
import lumars;
import nijiui.widgets;
import std.string;
import std.meta : AliasSeq;


private {
    bool uiBegun;

    alias GUI_API = AliasSeq!(
        "button", (string text) { return uiBegun && uiImButton(text.toStringz); },
        "label", (string text) { if (uiBegun) uiImLabel(text); },
        "textbox", (string id, string text) {
            return [LuaValue(uiImInputText(id, text)), LuaValue(text)]; 
        },
        "error", (string title, string text) { uiImDialog(title.toStringz, text); },
        "info", (string title, string text) { uiImDialog(title.toStringz, text, DialogLevel.Info); },
        "warn", (string title, string text) { uiImDialog(title.toStringz, text, DialogLevel.Warning); },
    );
}

void insRegisterUIAPI(LuaState* state) {
    state.register!GUI_API("ui");
}

void insPluginBegnijiui() {
    uiBegun = true;
}

void insPluginEndUI() {
    uiBegun = false;
}

