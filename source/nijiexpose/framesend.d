/*
    Copyright © 2022, Inochi2D Project
    Copyright © 2024, nijigenerate Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module nijiexpose.framesend;
import nijiexpose.log;
import nijilive;
import bindbc.opengl;
import i18n;
import std.format;
import std.string;

version(Windows) {
    import bindbc.spout2;
    import bindbc.spout2.types;
}

private {
    bool loadSuccessful;
    version(Windows) {
        SPOUTHANDLE spHandle;
    }
}

/**
    Initializes the frame sender system
*/
void insInitFrameSending() {
    version(Windows) {
        auto loadMode = loadSpout2();
        loadSuccessful = loadMode == Spout2Support.spout2;
        
        if (loadSuccessful) {
            string senderName = "Puppetstring Model Viewer";
            spHandle = spGetSpout();

            int i = 1;
            while (spFindSenderName(spHandle, cast(char*)senderName.toStringz)) {
                senderName = "Puppetstring Model Viewer (%s)".format(i);
            }

            spSetSenderName(spHandle, senderName.toStringz);
            spSetSenderFormat(spHandle, 28); // DXGI 8-bit RGBA
        }
    }

    if (!loadSuccessful) insLogErr(_("Could not start texture sharing, it will be disabled. Is the library missing?"));
    else insLogInfo(_("Frame-sending started successfully!"));
}

/**
    Cleans up the frame sender system
*/
void insCleanupFrameSending() {
    if (loadSuccessful) {
        version(Windows) {
            spReleaseSender(spHandle, 0);
            spHandle = null;
            unloadSpout2();
        }
    }
}

/**
    Sends a frame
*/
void insSendFrame() {
    if (loadSuccessful) {
        int w, h;
        inGetViewport(w, h);

        version(Windows) {
            if (spHandle) spSendTexture(spHandle, inGetRenderImage(), GL_TEXTURE_2D, w, h, true, inGetFramebuffer());
        }
    }
}

/**
    Gets whether low-overhead texture sharing is enabled.
*/
bool insCanSendFrames() {
    return loadSuccessful;
}
