"use strict";
/// <reference types="@figma/plugin-typings" />
let timer = null;
let frame = null;
let rectangle = null;
let currentURL = "";
let updateInterval = 1000; // in milliseconds
figma.ui.onmessage = async (msg) => {
    if (msg.type === "start") {
        currentURL = msg.url;
        updateInterval = 1000 / msg.frequency; // frequency is images per second
        createOrUpdateFrame();
        startUpdatingImage();
    }
    else if (msg.type === "stop") {
        stopUpdatingImage();
    }
    else if (msg.type === "updateSettings") {
        currentURL = msg.url;
        updateInterval = 1000 / msg.frequency;
        if (timer !== null) {
            stopUpdatingImage();
            startUpdatingImage();
        }
    }
};
function createOrUpdateFrame() {
    if (!frame) {
        frame = figma.createFrame();
        frame.name = "Live Image Frame";
        frame.resize(375, 812); // new default dimensions
        figma.currentPage.appendChild(frame);
    }
    // If there is no rectangle, create one
    if (!rectangle) {
        rectangle = figma.createRectangle();
        rectangle.resize(frame.width, frame.height);
        frame.appendChild(rectangle);
    }
    // Set an initial fill (so it doesn't start as white)
    /*rectangle.fills = [{
      type: "SOLID",
      color: { r: 0.9, g: 0.9, b: 0.9 }
    }];*/
    rectangle.fills = [];
}
async function fetchAndUpdate() {
    try {
        const response = await fetch(currentURL);
        if (!response.ok) {
            figma.notify(`Failed to fetch image. Status: ${response.status}`);
            return;
        }
        const arrayBuffer = await response.arrayBuffer();
        const imageBytes = new Uint8Array(arrayBuffer);
        const newImageHash = figma.createImage(imageBytes).hash;
        if (frame && rectangle) {
            // Create a new rectangle with the new image fill.
            const newRect = figma.createRectangle();
            newRect.resize(frame.width, frame.height);
            newRect.fills = [{
                    type: "IMAGE",
                    imageHash: newImageHash,
                    scaleMode: "FIT",
                    blendMode: "NORMAL"
                }];
            // Set new rectangle's opacity to 0 (fully transparent)
            newRect.opacity = 0;
            // Position it exactly over the old rectangle.
            newRect.x = rectangle.x;
            newRect.y = rectangle.y;
            frame.appendChild(newRect);
            // Crossfade settings: we only fade in the new rectangle.
            const fadeDuration = 300; // total fade duration in ms
            const fadeSteps = 15; // number of steps
            const stepTime = fadeDuration / fadeSteps;
            let step = 0;
            const fadeInterval = setInterval(() => {
                step++;
                const newOpacity = step / fadeSteps;
                newRect.opacity = newOpacity;
                if (step >= fadeSteps) {
                    clearInterval(fadeInterval);
                    newRect.opacity = 1; // fully opaque
                    // Remove the old rectangle only after new is fully visible.
                    if (rectangle) {
                        rectangle.remove();
                    }
                    rectangle = newRect;
                }
            }, stepTime);
        }
    }
    catch (err) {
        figma.notify(`Error fetching image: ${err}`);
    }
}
function startUpdatingImage() {
    if (timer !== null)
        return; // already running
    timer = setInterval(fetchAndUpdate, updateInterval);
    figma.notify("Live image updating started.");
}
function stopUpdatingImage() {
    if (timer !== null) {
        clearInterval(timer);
        timer = null;
        figma.notify("Live image updating stopped.");
    }
}
figma.showUI(__html__, { width: 300, height: 250 });
