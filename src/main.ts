import { vec3 } from 'gl-matrix';
import Stats from 'stats-js';
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import { setGL } from './globals';
import ShaderProgram, { Shader } from './rendering/gl/ShaderProgram';

import lambertVertSource from './shaders/lambert-vert.glsl?raw';
import lambertFragSource from './shaders/lambert-frag.glsl?raw';
import helpersSource from './shaders/helpers.glsl?raw';

const defaultColors = {
  dimColor: [250, 10, 10],         // 0.98, 0.04, 0.04
  blueColor: [10, 48, 171],        // 0.04, 0.19, 0.67
  shimmerBase: [8, 79, 245],       // 0.03, 0.31, 0.96
  shimmerTop: [255, 46, 46],       // 1.0, 0.18, 0.18
  bright1: [255, 189, 138],        // 1.0, 0.74, 0.54
  bright2: [255, 51, 0],           // 1.0, 0.2, 0.0
  topColor: [255, 0, 0]            // 1.0, 0.0, 0.0
};

// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  'Load Scene': loadScene, // A function pointer, essentially
  bloomAmount: 10,

  // Clone arrays to prevent reference issues
  dimColor: [...defaultColors.dimColor],
  blueColor: [...defaultColors.blueColor],
  shimmerBase: [...defaultColors.shimmerBase],
  shimmerTop: [...defaultColors.shimmerTop],
  bright1: [...defaultColors.bright1],
  bright2: [...defaultColors.bright2],
  topColor: [...defaultColors.topColor],

  'Restore Defaults': () => {
    controls.dimColor = [...defaultColors.dimColor];
    controls.blueColor = [...defaultColors.blueColor];
    controls.shimmerBase = [...defaultColors.shimmerBase];
    controls.shimmerTop = [...defaultColors.shimmerTop];
    controls.bright1 = [...defaultColors.bright1];
    controls.bright2 = [...defaultColors.bright2];
    controls.topColor = [...defaultColors.topColor];

    // Update the UI controllers
    for (let i in gui.__controllers) {
      gui.__controllers[i].updateDisplay();
    }
  }
};

let icosphere: Icosphere;
let square: Square;
let prevTesselations: number = 5;
let prevBloomAmount: number = 10;

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.add(controls, 'Load Scene');
  gui.add(controls, 'bloomAmount', 0, 20).step(1);

  const colorFolder = gui.addFolder('Shader Colors');
  colorFolder.addColor(controls, 'dimColor').name('Dim');
  colorFolder.addColor(controls, 'blueColor').name('Blue');
  colorFolder.addColor(controls, 'shimmerBase').name('Shimmer Base');
  colorFolder.addColor(controls, 'shimmerTop').name('Shimmer Top');
  colorFolder.addColor(controls, 'bright1').name('Bright 1');
  colorFolder.addColor(controls, 'bright2').name('Bright 2');
  colorFolder.addColor(controls, 'topColor').name('Top');

  gui.add(controls, 'Restore Defaults');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement>document.getElementById('canvas');
  const gl = <WebGL2RenderingContext>canvas.getContext('webgl2');
  gl.getExtension('EXT_color_buffer_float');

  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.0, 0.0, 0.0, 1);
  gl.enable(gl.DEPTH_TEST);

  const fragSource = lambertFragSource.replace(
    '#include "helpers.glsl"',
    helpersSource
  );

  const vertSource = lambertVertSource.replace(
    '#include "helpers.glsl"',
    helpersSource
  );

  console.log(fragSource);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, vertSource),
    new Shader(gl.FRAGMENT_SHADER, fragSource),
  ]);

  // This function will be called every frame
  function tick() {
    camera.update();
    stats.begin();

    lambert.setTime(performance.now() / 1000.0);

    lambert.setCameraPosition(camera.controls.eye);

    // Helper to convert dat.gui [0, 255] RGB arrays into WebGL [0, 1] vectors
    const normalizeColor = (c: number[]) => vec3.fromValues(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0);

    // Feed current GUI colors into the shader
    lambert.setFragColors(
      normalizeColor(controls.dimColor),
      normalizeColor(controls.blueColor),
      normalizeColor(controls.shimmerBase),
      normalizeColor(controls.shimmerTop),
      normalizeColor(controls.bright1),
      normalizeColor(controls.bright2),
      normalizeColor(controls.topColor)
    );

    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    if (controls.tesselations != prevTesselations) {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }
    renderer.render(camera, lambert, [
      icosphere,
      // square,
    ]);

    if (controls.bloomAmount != prevBloomAmount) {
      prevBloomAmount = controls.bloomAmount;

      renderer.setBloomAmount(prevBloomAmount);
    }

    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function () {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick();
}

main();
