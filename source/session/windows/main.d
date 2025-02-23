/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module session.windows.main;
import session.windows;
import session.scene;
import session.log;
import session.framesend;
import session.plugins;
import session.io;
import inui;
import inui.widgets;
import inui.toolwindow;
import inui.panel;
import inui.input;
import inochi2d;
import ft;
import i18n;
import inui.utils.link;
import std.format;
import session.ver;
import bindbc.opengl;

version(linux) import dportals;

private {
    struct InochiWindowSettings {
        int width;
        int height;
    }

    struct PuppetSavedData {
        float scale;
    }
}

class InochiSessionWindow : InApplicationWindow {
private:
    Adaptor adaptor;
    version (InBranding) Texture logo;

    void loadModels(string[] args) {
        foreach(arg; args) {
            import std.file : exists;
            if (!exists(arg)) continue;
            try {
                insSceneAddPuppet(arg, inLoadPuppet(arg));
            } catch(Exception ex) {
                uiImDialog(__("Error"), "Could not load %s, %s".format(arg, ex.msg));
            }
        }
    }

protected:
    override
    void onEarlyUpdate() {
        insUpdateScene();
        insSendFrame();
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        inDrawScene(vec4(0, 0, width, height));
    }

    override
    void onUpdate() {
        if (!inInputIsInUI()) {
            if (inInputMouseDoubleClicked(MouseButton.Left)) this.showUI = !showUI;
            insInteractWithScene();

            /* disable drag and drop

            if (getDraggedFiles().length > 0) {
                loadModels(getDraggedFiles());
            }

            */
        }

        if (showUI) {
            uiImBeginMainMenuBar();
                vec2 avail = uiImAvailableSpace();

                /* remove logo and file
                version (InBranding) {
                    uiImImage(logo.getTextureId(), vec2(avail.y*2, avail.y*2));
                }

                if (uiImBeginMenu(__("File"))) {

                    if (uiImMenuItem(__("Open"))) {
                        const TFD_Filter[] filters = [
                            { ["*.inp"], "Inochi2d Puppet (*.inp)" }
                        ];

                        string parentWindow = "";
                        version(linux) {
                            static if (is(typeof(&getWindowHandle))) {
                                parentWindow = getWindowHandle();
                            }
                        }
                        string file = insShowOpenDialog(filters, _("Open..."), parentWindow);
                        if (file) loadModels([file]);
                    }

                    uiImSeperator();

                    if (uiImMenuItem(__("Exit"))) {
                        this.close();
                    }

                    uiImEndMenu();
                }

                */

                if (uiImBeginMenu(__("View"))) {

                    /* remove panels separator

                    uiImLabelColored(_("Panels"), vec4(0.8, 0.3, 0.3, 1));
                    uiImSeperator();

                    */

                    foreach(panel; inPanels) {
                        if (uiImMenuItem(panel.displayNameC, "", panel.visible)) {
                            panel.visible = !panel.visible;
                        }
                    }

                    /* remove virtual space
                    
                    uiImNewLine();

                    uiImLabelColored(_("Configuration"), vec4(0.8, 0.3, 0.3, 1));
                    uiImSeperator();
                    if (uiImMenuItem(__("Virtual Space"))) {
                        inPushToolWindow(new SpaceEditor());
                    }

                    */

                    uiImEndMenu();
                }

                if (uiImBeginMenu(__("Tools"))) {

                    // Resets the tracking out range to be in the coordinate space of min..max
                    if (uiImMenuItem(__("Reset Tracking Out"))) {
                        if (insSceneSelectedSceneItem()) {
                            foreach(ref binding; insSceneSelectedSceneItem.bindings) {
                                binding.outRangeToDefault();
                            }
                        }
                    }
                    uiImEndMenu();
                }

                /* remove plugins and help

                if (uiImBeginMenu(__("Plugins"))) {

                    uiImLabelColored(_("Plugins"), vec4(0.8, 0.3, 0.3, 1));
                    uiImSeperator();

                    foreach(plugin; insPlugins) {
                        if (uiImMenuItem(plugin.getCName, "", plugin.isEnabled)) {
                            plugin.isEnabled = !plugin.isEnabled;
                            insSavePluginState();
                        }
                    }

                    uiImNewLine();

                    uiImLabelColored(_("Tools"), vec4(0.8, 0.3, 0.3, 1));
                    uiImSeperator();
                    if (uiImMenuItem(__("Rescan Plugins"))) {
                        insEnumeratePlugins();
                    }

                    uiImEndMenu();
                }


                if (uiImBeginMenu(__("Help"))) {
                    if (uiImMenuItem(__("Documentation"))) {
                        uiOpenLink("https://github.com/Inochi2D/inochi-session/wiki");
                    }
                    if (uiImMenuItem(__("About"))) {
                        uiImDialog(__("Inochi Session"),
                        "Inochi Session %s\n(Inochi2D %s)\n\nMade with <3\nby Luna the Foxgirl and Inochi2D Contributors.".format(INS_VERSION, IN_VERSION), DialogLevel.Info);
                    }
                    
                    uiImEndMenu();
                }

                */

                uiImDummy(vec2(4, 0));
                uiImSeperator();
                uiImDummy(vec2(4, 0));
                uiImLabel(_("Double-click to Toggle Developer/Rigger Tools"));

                /* remove the rest

                // DONATE BUTTON
                avail = uiImAvailableSpace();
                vec2 donateBtnLength = uiImMeasureString(_("Donate")).x+16;
                uiImDummy(vec2(avail.x-donateBtnLength.x, 0));
                if (uiImMenuItem(__("Donate"))) {
                    uiOpenLink("https://www.patreon.com/LunaFoxgirlVT");
                }

                */
                
            uiImEndMainMenuBar();
        }

        version(linux) dpUpdate();
    }

    override
    void onResized(int w, int h) {
        inSetViewport(w, h);
        inSettingsSet("window", InochiWindowSettings(width, height));
    }

    override
    void onClosed() {
    }

public:

    /**
        Construct Inochi Session
    */
    this(string[] args) {
        InochiWindowSettings windowSettings = 
            inSettingsGet!InochiWindowSettings("window", InochiWindowSettings(1024, 1024));

        import session.ver;
        super("Puppetstring Model Viewer", windowSettings.width, windowSettings.height);
        
        // Initialize Inochi2D
        inInit(&inGetTime);
        inSetViewport(windowSettings.width, windowSettings.height);

        // Preload any specified models
        loadModels(args);

        // uiImDialog(
        //     __("Inochi Session"), 
        //     _("THIS IS BETA SOFTWARE\n\nThis software is incomplete, please lower your expectations."), 
        //     DialogLevel.Warning
        // );

        inGetCamera().scale = vec2(0.5);

        version (InBranding) {
            logo = new Texture(ShallowTexture(cast(ubyte[])import("tex/logo.png")));
        }

        version(linux) dpInit();
    }
}