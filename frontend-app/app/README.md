# Introduction 
This is a React web app.

# Getting Started
After cloning, run 'npm install'.

# Build and Test
To test, run 'npm start'.
To build, run 'npm run build --prod --nomaps'.  Then copy/paste the contents of the Build folder into the public folder of the ues-messages-app.

# Notes
The blob storage CORS requires GET and HEAD

# Contribute

# zone editor
press 1, 2 or 3 to edit by point, edge or shape
mouse over a point/edge/shape to select for editing
a selected point/edge/shape is highlighted in yellow

to edit by point:
click to add a point
click, hold and drag to move a selected point
press delete to delete a selected point
press insert to insert a point after a selected point

to edit by edge:
click, hold and drag to move a selected edge

to edit by shape:
click, hold and drag to move a selected shape

# WASM: compile collision.cpp to collision.js
Download and install the latest emsdk at https://emscripten.org/docs/getting_started/downloads.html
To compile, using the cmd/terminal:
    cd to the emsdk folder
    run emcmdprompt.bat
    cd to the ues-app/app folder
    run emcc src/models/collision.cpp -s WASM=1 -s "EXPORTED_FUNCTIONS=['_main', '_isBBoxInZone']" -o public/collision.js
Copy/paste into index.html in head:
    <script async type="text/javascript" src="collision.js"></script>
    <script>
        window.Module = Module;
    </script>