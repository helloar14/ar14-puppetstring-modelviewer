/*
    nijiexpose main app entry
    
    Copyright © 2022, Inochi2D Project
    Copyright © 2024, nijigenerate Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module app;
import nijilive;
import nijiui;
import nijiexpose.windows;
import std.stdio : writeln;
import nijiexpose.plugins;
import nijiexpose.log;
import nijiexpose.ver;
import nijiexpose.scene;
import nijiexpose.framesend;
import nijiexpose.tracking.expr;
import nijiexpose.tracking.tracker;
import std.process;

void main(string[] args) {
    insLogInfo("Puppetstring Model Viewer %s, args=%s", INS_VERSION, args[1..$]);

    // Set the application info
    InApplication appInfo = InApplication(
        "net.ar14.puppetstring-modelviewer",   // FQDN
        "puppetstring-modelviewer",               // Config dir
        "Puppetstring Model Viewer"                // Human-readable name
    );
    inSetApplication(appInfo);

    // Initialize Lua
    insLuaInit();
    
    // Initialize UI
    inInitUI();

    // Initialize expressions before models are loaded.
    insInitExpressions();

    //neInitTracker();

    // Open window and init nijilive
    auto window = neCreateWindow(args[1..$]);
    
    insScene.init();
    insInitFrameSending();
    inPostProcessingAddBasicLighting();

    // Draw window
    while(window.isAlive) {
        window.update();
    }
    
    insCleanupExpressions();
    insLuaUnload();
    insCleanupFrameSending();
    insScene.cleanup();
    inSettingsSave();
    //neShutdownTracker();
}
