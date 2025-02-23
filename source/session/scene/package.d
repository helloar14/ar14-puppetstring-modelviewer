/*
    Copyright © 2022, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module session.scene;
import inochi2d;
import inui.input;
import inui;
import session.tracking;
import session.animation;
import session.tracking.vspace;
import session.panels.tracking : insTrackingPanelRefresh;
import session.log;
import std.string;
import session.plugins;
import session.render.spritebatch;
import bindbc.opengl;
import inochi2d.core.animation.player;
import std.math.operations : isClose;

struct Scene {
    VirtualSpace space;
    SceneItem[] sceneItems;

    string bgPath;
    Texture backgroundImage;

    bool shouldPostProcess = true;
    float zoneInactiveTimer = 0;

    bool sleeping = false;
}

struct SceneItem {
    string filePath;
    Puppet puppet;
    TrackingBinding[] bindings;
    AnimationControl[] animations;
    AnimationPlayer player;

    void saveBindings() {
        puppet.extData["com.inochi2d.inochi-session.bindings"] = cast(ubyte[])serializeToJson(bindings);
        inWriteINPExtensions(puppet, filePath);
    }

    void saveAnimations() {
        puppet.extData["com.inochi2d.inochi-session.animations"] = cast(ubyte[])serializeToJson(animations);
        inWriteINPExtensions(puppet, filePath);
    }

    bool tryLoadBindings() {
        if ("com.inochi2d.inochi-session.bindings" in puppet.extData) {
            auto preBindings = deserialize!(TrackingBinding[])(cast(string)puppet.extData["com.inochi2d.inochi-session.bindings"]);

            // finalize the loading
            bindings = [];
            foreach(ref binding; preBindings) {
                if (binding.finalize(puppet)) {
                    bindings ~= binding;
                }
            }
            return true;
        }
        return false;
    }

    bool tryLoadAnimations() {
        if ("com.inochi2d.inochi-session.animations" in puppet.extData) {
            auto preAnimation = deserialize!(AnimationControl[])(cast(string)puppet.extData["com.inochi2d.inochi-session.animations"]);

            // finalize the loading
            animations = [];
            foreach(ref animation; preAnimation) {
                if (animation.finalize(player)) {
                    animations ~= animation;
                }
            }
            return true;
        }
        return false;
    }

    void genBindings() {
        struct LinkSrcDst {
            Parameter dst;
            int outAxis;
        }
        LinkSrcDst[] srcDst;

        // Note down link targets
        // foreach(param; puppet.parameters) {
        //     foreach(ref ParamLink link; param.links) {
        //         srcDst ~= LinkSrcDst(link.link, cast(int)link.outAxis);
        //     }
        // }

        // Note existing bindings
        foreach(ref binding; bindings) {
            srcDst ~= LinkSrcDst(binding.param, binding.axis);
        }

        bool isParamAxisLinked(Parameter dst, int axis) {
            foreach(ref LinkSrcDst link; srcDst) {
                if (link.dst == dst && axis == link.outAxis) return true;
            }
            return false;
        }

        mforeach: foreach(ref Parameter param; puppet.parameters) {

            // Skip all params affected by physics
            foreach(ref Driver driver; puppet.getDrivers()) 
                if (driver.affectsParameter(param)) continue mforeach;
            

            // Loop over X/Y for parameter
            int imax = param.isVec2 ? 2 : 1;
            for (int i = 0; i < imax; i++) {
                if (isParamAxisLinked(param, i)) continue;
                
                TrackingBinding binding = new TrackingBinding();
                binding.param = param;
                binding.axis = i;
                binding.type = BindingType.RatioBinding;
                binding.inRange = vec2(0, 1);
                binding.outRangeToDefault();

                // binding name assignment
                if (param.isVec2) binding.name = "%s (%s)".format(param.name, i == 0 ? "X" : "Y");
                else binding.name = param.name;

                bindings ~= binding;
            }
        }
    }

    void genAnimationControls() {
        AnimationControl[string] acs; 
        foreach(ref ac; animations) {
            acs[ac.name] = ac;
        }

        foreach(name, ref anim; puppet.getAnimations()) {
            if(name !in acs){
                AnimationControl ac = new AnimationControl();
                ac.name = name;
                ac.finalize(player);

                animations ~= ac;
            }
        }

    }

    void sleep(){
        foreach(ref animation; animations) {
            animation.sleep();
        }
    }

    void awake(){
        foreach(ref animation; animations) {
            animation.awake();
        }
    }
}

/**
    List of puppets
*/
Scene insScene;

void insSceneAddPuppet(string path, Puppet puppet) {

    import std.format : format;
    SceneItem item;
    item.filePath = path;
    item.puppet = puppet;
    item.player = new AnimationPlayer(puppet);
    
    if (!item.tryLoadBindings()) {
        // Reset bindings
        item.bindings.length = 0;
    }
    if (!item.tryLoadAnimations()) {
        // Reset animations
        item.animations.length = 0;
    }

    item.genBindings();
    item.genAnimationControls();

    if(insScene.sleeping) item.sleep();
    insScene.sceneItems ~= item;
}

void insSceneInit() {
    insScene.space = insLoadVSpace();
    auto tex = ShallowTexture(cast(ubyte[])import("tex/ui-delete.png"));
    inTexPremultiply(tex.data);
    trashcanTexture = new Texture(tex);
    AppBatch = new SpriteBatch();

    insScene.bgPath = inSettingsGet!string("bgPath");
    if (insScene.bgPath) {
        try {
            tex = ShallowTexture(insScene.bgPath);
            if (tex.channels == 4) {
                inTexPremultiply(tex.data);
            }
            insScene.backgroundImage = new Texture(tex);
        } catch (Exception ex) {
            insLogErr("%s", ex.msg);
        }
    }

    insScene.shouldPostProcess = inSettingsGet!(bool)("shouldPostProcess", true);
    
    float[3] ambientLight = inSettingsGet!(float[3])("ambientLight", [1, 1, 1]);
    inSceneAmbientLight.vector = ambientLight;

    float[4] bgColor = inSettingsGet!(float[4])("bgColor", [0, 0, 0, 0]);
    inSetClearColor(bgColor[0], bgColor[1], bgColor[2], bgColor[3]);
}

void insSceneCleanup() {
    insSaveVSpace(insScene.space);

    foreach(ref source; insScene.space.getAllSources()) {
        if (source) {
            if (source.isRunning()) {
                source.stop();
            }
            destroy(source);
        }
    }
}

void insUpdateScene() {
    // Get viewport
    int viewportWidth, viewportHeight;
    inGetViewport(viewportWidth, viewportHeight);

    // Update physics managment
    inUpdate();

    // Update virtual spaces
    insScene.space.update();

    // Scene Colors
    float[4] sceneBGColor = [0, 0, 0, 0];
    float[3] sceneLighting = [1, 1, 1];
    
    if (insScene.space.currentZone) {

        sceneBGColor[0] = insScene.space.currentZone.getBlendshapeFor("psBackgroundRed");
        sceneBGColor[1] = insScene.space.currentZone.getBlendshapeFor("psBackgroundGreen");
        sceneBGColor[2] = insScene.space.currentZone.getBlendshapeFor("psBackgroundBlue");
        sceneBGColor[3] = insScene.space.currentZone.getBlendshapeFor("psBackgroundAlpha");

        inSetClearColor(sceneBGColor[0], sceneBGColor[1], sceneBGColor[2], sceneBGColor[3]);

        float enablePrecisionTransform = insScene.space.currentZone.getBlendshapeFor("psEnablePrecisionTransform");

        if (enablePrecisionTransform == 1) {

            foreach(i, ref sceneItem; insScene.sceneItems) {
    
                auto puppet = sceneItem.puppet;
    
                puppet.transform.scale.x = insScene.space.currentZone.getBlendshapeFor("psModelScaleX");
                puppet.transform.scale.y = insScene.space.currentZone.getBlendshapeFor("psModelScaleY");
    
                puppet.transform.translation.x = insScene.space.currentZone.getBlendshapeFor("psModelTranslationX");
                puppet.transform.translation.y = insScene.space.currentZone.getBlendshapeFor("psModelTranslationY");
                    
            }

        }

        float enableAmbientLight = insScene.space.currentZone.getBlendshapeFor("psEnableAmbientLight");

        if (enableAmbientLight == 1) {

            insScene.shouldPostProcess = true;
    
            sceneLighting[0] = insScene.space.currentZone.getBlendshapeFor("psAmbientLightRed");
            sceneLighting[1] = insScene.space.currentZone.getBlendshapeFor("psAmbientLightGreen");
            sceneLighting[2] = insScene.space.currentZone.getBlendshapeFor("psAmbientLightBlue");
    
            inSceneAmbientLight.vector = sceneLighting;

        } else if (insScene.shouldPostProcess) {

            insScene.shouldPostProcess = false;

            inSceneAmbientLight.vector = [1, 1, 1];

        }

    }

    /* remove trash can

    // Render the waifu trashcan outside of the main FB
    glEnable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glClear(GL_COLOR_BUFFER_BIT);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    trashcanVisibility = dampen(trashcanVisibility, isDragDown ? 0.85 : 0, deltaTime(), 1);
    {
        float trashcanScale = 1f;
        float sizeOffset = 0f;


        if (isMouseOverDelete) {
            float scalePercent = (sin(currentTime()*2)+1)/2;
            trashcanScale += 0.15*scalePercent;
            sizeOffset = ((trashcanSize*trashcanScale)-trashcanSize)/2;
        }

        AppBatch.draw(
            trashcanTexture,
            rect(
                TRASHCAN_DISPLACEMENT-sizeOffset, 
                viewportHeight-(trashcanSize+TRASHCAN_DISPLACEMENT+sizeOffset),
                trashcanSize*trashcanScale, 
                trashcanSize*trashcanScale
            ),
            rect.init,
            vec2(0),
            0,
            SpriteFlip.None,
            vec4(1, 1, 1, trashcanVisibility)
        );
        AppBatch.flush();
        glFlush();
    }
    glDisable(GL_BLEND);

    */

    inBeginScene();

        if (insScene.backgroundImage) {
            float texWidth = insScene.backgroundImage.width;
            float texHeight = insScene.backgroundImage.height;
            
            float scale = max(cast(float)viewportWidth/cast(float)texWidth, cast(float)viewportHeight/cast(float)texHeight);
            
            rect bounds = rect(
                0,
                0,
                texWidth*scale,
                texHeight*scale
            );

            bounds.x = (viewportWidth/2);
            bounds.y = (viewportHeight/2);
            
            AppBatch.draw(
                insScene.backgroundImage,
                bounds,
                rect.init,
                vec2(bounds.width/2, bounds.height/2)
            );
            AppBatch.flush();
        }
        
        // Update plugins
        foreach(ref plugin; insPlugins) {
            if (!plugin.isEnabled) continue;

            if (plugin.hasEvent("onUpdate")) {
                plugin.callEvent("onUpdate", deltaTime());
            }
        }

        
        if (!insScene.space.isCurrentZoneActive()) {
            insScene.zoneInactiveTimer += deltaTime();
            if (insScene.zoneInactiveTimer >= 5) {
                if(!insScene.sleeping){
                    foreach(ref sceneItem; insScene.sceneItems) {
                        sceneItem.sleep();
                    }
                    insScene.sleeping = true;
                }
            }
        } else {
            insScene.zoneInactiveTimer -= deltaTime();
            // Stop sleep animation
            if (insScene.sleeping) {
                foreach(ref sceneItem; insScene.sceneItems) {
                    sceneItem.awake();
                }
                insScene.sleeping = false;
            }
        }
        insScene.zoneInactiveTimer = clamp(insScene.zoneInactiveTimer, 0, 6);

        // Update every scene item
        foreach(ref sceneItem; insScene.sceneItems) {
            
            foreach(ref binding; sceneItem.bindings) {
                binding.update();
            }

            foreach(ref ac; sceneItem.animations) {
                ac.update();
            }

            sceneItem.player.update(deltaTime());
            sceneItem.puppet.update();
            sceneItem.puppet.draw();
            
            foreach(ref binding; sceneItem.bindings) {
                binding.lateUpdate();
            }
        }
    inEndScene();

    if (insScene.shouldPostProcess) {
        inPostProcessScene();
    }
}

/**
    Returns a pointer to the active scene item
*/
SceneItem* insSceneSelectedSceneItem() {
    if (selectedPuppet < 0 || selectedPuppet > insScene.sceneItems.length) return null;
    return &insScene.sceneItems[selectedPuppet];
}

private {
    ptrdiff_t selectedPuppet = -1;
    Puppet draggingPuppet;
    vec2 draggingPuppetStartPos;
    bool hasDonePuppetSelect;
    vec2 targetPos = vec2(0);
    float targetScale = 0;
    vec2 targetSize = vec2(0);

    bool isDragDown = false;
    Camera inCamera;

    enum TRASHCAN_DISPLACEMENT = 16;
    float trashcanVisibility = 0;
    float trashcanSize = 64;
    Texture trashcanTexture;
    rect deleteArea;
    bool isMouseOverDelete;
}

void insInteractWithScene() {

    // Skip doing stuff is mouse drag begin in the UI
    if (inInputMouseDownBeganInUI(MouseButton.Left)) return;

    int width, height;
    inGetViewport(width, height);
    
    deleteArea = rect(0, height-(TRASHCAN_DISPLACEMENT+trashcanSize), trashcanSize+TRASHCAN_DISPLACEMENT, trashcanSize+TRASHCAN_DISPLACEMENT);
    isMouseOverDelete = deleteArea.intersects(inInputMousePosition());

    import std.stdio : writeln;
    inCamera = inGetCamera();
    vec2 mousePos = inInputMousePosition();
    vec2 mouseOffset = vec2(width/2, height/2);
    vec2 cameraCenter = inCamera.getCenterOffset();
    mousePos = vec2(
        vec4(
            (mousePos.x-mouseOffset.x+inCamera.position.x)/inCamera.scale.x,
            (mousePos.y-mouseOffset.y+inCamera.position.y)/inCamera.scale.y,
            0, 
            1
        )
    );

    if (!inInputWasMouseDown(MouseButton.Left) && inInputMouseDown(MouseButton.Left)) {

        // One shot check if there's a puppet to drag under the cursor
        if (!hasDonePuppetSelect) {
            hasDonePuppetSelect = true;
            draggingPuppet = null;

            // For performance sake we should disable bounds calculation after we're done getting drag state.
            inSetUpdateBounds(true);
                bool selectedAny = false;
                foreach(i, ref sceneItem; insScene.sceneItems) {

                    auto puppet = sceneItem.puppet;

                    // Calculate on-screen bounds of the object
                    vec4 lbounds = puppet.getCombinedBounds!true();
                    vec2 tl = vec4(lbounds.xy, 0, 1);
                    vec2 br = vec4(lbounds.zw, 0, 1);
                    vec2 size = abs(br-tl);
                    rect bounds = rect(tl.x, tl.y, size.x, size.y);

                    if (bounds.intersects(mousePos)) {
                        draggingPuppetStartPos = puppet.transform.translation.xy;
                        targetScale = puppet.transform.scale.x;
                        targetPos = draggingPuppetStartPos;
                        targetSize = size;
                        draggingPuppet = puppet;
                        selectedPuppet = i;
                        selectedAny = true;
                        insTrackingPanelRefresh();
                    }
                }
                if (!selectedAny) {
                    selectedPuppet = -1;
                    draggingPuppet = null;
                    insTrackingPanelRefresh();
                }
            inSetUpdateBounds(false);
            
        }
    } else if (!inInputMouseDown(MouseButton.Left) && hasDonePuppetSelect) {
        hasDonePuppetSelect = false;
    }

    // Model Scaling
    if (hasDonePuppetSelect && draggingPuppet) {
        import bindbc.imgui : igSetMouseCursor, ImGuiMouseCursor;
        igSetMouseCursor(ImGuiMouseCursor.Hand);
        float prevScale = targetScale;

        float targetDelta = (inInputMouseScrollDelta()*0.05)*(1-clamp(targetScale, 0, 0.45));
        targetScale = clamp(
            targetScale+targetDelta, 
            0.25,
            5
        );
        
        if (targetScale != prevScale) {
            inSetUpdateBounds(true);
                vec4 lbounds = draggingPuppet.transform.matrix*draggingPuppet.getCombinedBounds!true();
                vec2 tl = vec4(lbounds.xy, 0, 1);
                vec2 br = vec4(lbounds.zw, 0, 1);
                targetSize = abs(br-tl);
            inSetUpdateBounds(false);
        }
    }

    // Model Movement
    if (inInputMouseDragging(MouseButton.Left) && hasDonePuppetSelect && draggingPuppet) {
        vec2 delta = inInputMouseDragDelta(MouseButton.Left);
        targetPos = vec2(
            draggingPuppetStartPos.x+delta.x/inCamera.scale.x, 
            draggingPuppetStartPos.y+delta.y/inCamera.scale.y, 
        );
    }
    
    // Model clamping
    {
        float camPosClampX = (cameraCenter.x*2)+(targetSize.x/3);
        float camPosClampY = (cameraCenter.y*2)+(targetSize.y/1.5);

        // Clamp model to be within viewport
        targetPos.x = clamp(
            targetPos.x,
            (inCamera.position.x-camPosClampX)*inCamera.scale.x,
            (inCamera.position.x+camPosClampX)*inCamera.scale.x
        );
        targetPos.y = clamp(
            targetPos.y,
            (inCamera.position.y-camPosClampY)*inCamera.scale.y,
            (inCamera.position.y+camPosClampY)*inCamera.scale.y
        );
    }

    // Apply Movement + Scaling
    if (draggingPuppet) {
        if (isMouseOverDelete) {

            // If the mouse was let go
            if (isDragDown && !inInputMouseDown(MouseButton.Left)) {
                if (selectedPuppet >= 0 && selectedPuppet < insScene.sceneItems.length) {
                    
                    import std.algorithm.mutation : remove;
                    insScene.sceneItems = insScene.sceneItems.remove(selectedPuppet);
                    draggingPuppet = null;
                    selectedPuppet = -1;
                    isDragDown = false;
                    return;
                }
            }
        }

        isDragDown = inInputMouseDown(MouseButton.Left);

        import bindbc.imgui : igIsKeyDown, ImGuiKey;
        if (igIsKeyDown(ImGuiKey.LeftCtrl) || igIsKeyDown(ImGuiKey.RightCtrl)) {
            float targetDelta = (inInputMouseScrollDelta()*0.05)*(1-clamp(targetScale, 0, 0.45));
            targetScale = clamp(
                targetScale+targetDelta, 
                0.25,
                5
            );
        }

        /* disable model deletion
        

        if (isDragDown && isMouseOverDelete) {
            

            draggingPuppet.transform.translation = dampen(
                draggingPuppet.transform.translation,
                vec3(
                    (inCamera.position.x+(-cameraCenter.x)+128), 
                    (inCamera.position.y+(cameraCenter.y)-128), 
                    0
                ),
                inGetDeltaTime()
            );

            // Dampen & clamp scaling
            draggingPuppet.transform.scale = dampen(
                draggingPuppet.transform.scale,
                vec2(0.025),
                inGetDeltaTime()
            );
        } else {

        */

            draggingPuppet.transform.translation = dampen(
                draggingPuppet.transform.translation,
                vec3(targetPos, 0),
                inGetDeltaTime()
            );

            // Dampen & clamp scaling
            draggingPuppet.transform.scale = dampen(
                draggingPuppet.transform.scale,
                vec2(targetScale),
                inGetDeltaTime()
            );
        //}
    } else isDragDown = false;
}
