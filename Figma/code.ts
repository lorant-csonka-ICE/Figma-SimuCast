/// <reference types="@figma/plugin-typings" />

let timer: number | null = null;
let frame: FrameNode | null = null;
let rectangle: RectangleNode | null = null;
let currentURL: string = "";
let updateInterval: number = 1000; // in milliseconds

figma.ui.onmessage = async msg => {
  if (msg.type === "start") {
    currentURL = msg.url;
    updateInterval = 1000 / msg.frequency; // frequency is images per second
    createOrUpdateFrame();
    startUpdatingImage();
  } else if (msg.type === "stop") {
    stopUpdatingImage();
  } else if (msg.type === "updateSettings") {
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
  rectangle.fills = [{
    type: "SOLID",
    color: { r: 0.9, g: 0.9, b: 0.9 }
  }];
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
    
    // If there is already a rectangle, create a new one for smooth transition
    if (frame && rectangle) {
      const newRect = figma.createRectangle();
      newRect.resize(frame.width, frame.height);
      newRect.fills = [{
        type: "IMAGE",
        imageHash: newImageHash,
        scaleMode: "FIT",
        blendMode: "NORMAL",
        opacity: 1
      }];
      // Position newRect exactly over the old rectangle
      newRect.x = rectangle.x;
      newRect.y = rectangle.y;
      // Append newRect so it appears on top
      frame.appendChild(newRect);
      
      // Optionally, you could animate the opacity transition here with setTimeout/setInterval.
      // For simplicity, we just swap after a short delay:
      setTimeout(() => {
        if (rectangle) {
            rectangle.remove();
        }
        rectangle = newRect; // Update the reference to the new rectangle
    }, 50);
    }
  } catch (err) {
    figma.notify(`Error fetching image: ${err}`);
  }
}

function startUpdatingImage() {
  if (timer !== null) return; // already running
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