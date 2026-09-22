import { mat4, vec2, vec4 } from 'gl-matrix';
import Drawable from './Drawable';
import Camera from '../../Camera';
import { gl } from '../../globals';
import ShaderProgram, { Shader } from './ShaderProgram';
import Framebuffer from './Framebuffer';
import Square from '../../geometry/Square';

import brightpassFragSource from '../../shaders/brightpass.glsl?raw';
import fullscreenQuadVertSource from '../../shaders/fullscreen-vert.glsl?raw';

import gaussianBlurFragSource from '../../shaders/gaussianblurpassseparable.glsl?raw';

import simplepassFragSource from '../../shaders/simplepass.glsl?raw';

// In this file, `gl` is accessible because it is imported above
class OpenGLRenderer {
  sceneFBO: Framebuffer;
  brightpassFBO: Framebuffer;
  blurFBO1: Framebuffer;
  blurFBO2: Framebuffer;

  fullscreenQuad: Square;

  simplepassProg: ShaderProgram;
  brightpassProg: ShaderProgram;
  gaussianBlurProg: ShaderProgram;

  bloomIterations: number = 7;

  constructor(public canvas: HTMLCanvasElement) {
    this.sceneFBO = new Framebuffer(canvas.width, canvas.height);
    this.brightpassFBO = new Framebuffer(canvas.width, canvas.height);
    this.blurFBO1 = new Framebuffer(canvas.width, canvas.height);
    this.blurFBO2 = new Framebuffer(canvas.width, canvas.height);

    this.fullscreenQuad = new Square(vec4.fromValues(0, 0, 0, 1));
    this.fullscreenQuad.create();

    this.simplepassProg = new ShaderProgram([
      new Shader(gl.VERTEX_SHADER, fullscreenQuadVertSource),
      new Shader(gl.FRAGMENT_SHADER, simplepassFragSource),
    ]);

    this.brightpassProg = new ShaderProgram([
      new Shader(gl.VERTEX_SHADER, fullscreenQuadVertSource),
      new Shader(gl.FRAGMENT_SHADER, brightpassFragSource),
    ]);

    this.gaussianBlurProg = new ShaderProgram([
      new Shader(gl.VERTEX_SHADER, fullscreenQuadVertSource),
      new Shader(gl.FRAGMENT_SHADER, gaussianBlurFragSource),
    ]);

  }

  setClearColor(r: number, g: number, b: number, a: number) {
    gl.clearColor(r, g, b, a);
  }

  setBloomAmount(amount: number) {
    this.bloomIterations = amount;
  }

  setSize(width: number, height: number) {
    this.canvas.width = width;
    this.canvas.height = height;

    this.sceneFBO.resize(width, height);
    this.brightpassFBO.resize(width, height);

    this.blurFBO1.resize(width, height);
    this.blurFBO2.resize(width, height);
  }

  clear() {
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
  }

  drawIntoFBO(camera: Camera, prog: ShaderProgram, drawables: Array<Drawable>, frameBuffer: Framebuffer | null) {
    gl.bindFramebuffer(gl.FRAMEBUFFER, frameBuffer?.fbo || null);
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);

    this.clear();
    let model = mat4.create();
    let viewProj = mat4.create();
    let color = vec4.fromValues(1, 1, 1, 1);

    mat4.identity(model);
    mat4.multiply(viewProj, camera.projectionMatrix, camera.viewMatrix);

    prog.setModelMatrix(model);
    prog.setViewProjMatrix(viewProj);
    prog.setGeometryColor(color);

    for (let drawable of drawables) {
      prog.draw(drawable);
    }
  }

  postProcess(prog: ShaderProgram, framebufferFrom: Framebuffer | null, framebufferTo: Framebuffer | null,
    clearScreen: boolean = true
  ) {
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebufferTo?.fbo || null);
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);

    if (clearScreen) {
      this.clear();
    }

    gl.activeTexture(gl.TEXTURE0);

    if (framebufferFrom) {
      gl.bindTexture(
        gl.TEXTURE_2D,
        framebufferFrom.texture
      );
    }

    const imageHandle = gl.getUniformLocation(
      prog.prog,
      "u_Image"
    );

    prog.use();

    if (imageHandle !== null) {
      gl.uniform1i(imageHandle, 0);
    }

    // Draw fullscreen quad
    prog.draw(this.fullscreenQuad);
  }

  blur(framebufferFrom: Framebuffer | null, framebufferTo: Framebuffer | null, direction: vec2) {
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebufferTo?.fbo || null);
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);

    this.clear();

    gl.activeTexture(gl.TEXTURE0);

    if (framebufferFrom) {
      gl.bindTexture(
        gl.TEXTURE_2D,
        framebufferFrom.texture
      );
    }

    const imageHandle = gl.getUniformLocation(
      this.gaussianBlurProg.prog,
      "u_Image"
    );

    this.gaussianBlurProg.use();

    if (imageHandle !== null) {
      gl.uniform1i(imageHandle, 0);
    }

    const blurDirectionHandle = gl.getUniformLocation(
      this.gaussianBlurProg.prog,
      "uDirection"
    );

    if (blurDirectionHandle !== null) {
      gl.uniform2fv(blurDirectionHandle, direction);
    }

    const resolutionHandle = gl.getUniformLocation(
      this.gaussianBlurProg.prog,
      "uResolution"
    );

    if (resolutionHandle !== null) {
      gl.uniform2fv(resolutionHandle, vec2.fromValues(this.canvas.width, this.canvas.height));
    }

    // Draw fullscreen quad
    this.gaussianBlurProg.draw(this.fullscreenQuad);
  }

  composite(framebufferScene: Framebuffer | null, framebufferBloom: Framebuffer | null) {
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);

    this.clear();

    gl.activeTexture(gl.TEXTURE0);

    if (framebufferScene) {
      gl.bindTexture(
        gl.TEXTURE_2D,
        framebufferScene.texture
      );
    }

    const sceneHandle = gl.getUniformLocation(
      this.simplepassProg.prog,
      "u_Scene"
    );

    this.simplepassProg.use();

    if (sceneHandle !== null) {
      gl.uniform1i(sceneHandle, 0);
    }

    gl.activeTexture(gl.TEXTURE1);

    if (framebufferBloom) {
      gl.bindTexture(
        gl.TEXTURE_2D,
        framebufferBloom.texture
      );
    }

    const bloomHandle = gl.getUniformLocation(
      this.simplepassProg.prog,
      "u_Bloom"
    );

    if (bloomHandle !== null) {
      gl.uniform1i(bloomHandle, 1);
    }

    // Draw fullscreen quad
    this.simplepassProg.draw(this.fullscreenQuad);
  }

  render(camera: Camera, prog: ShaderProgram, drawables: Array<Drawable>) {
    this.drawIntoFBO(camera, prog, drawables, this.sceneFBO);
    this.postProcess(this.brightpassProg, this.sceneFBO, this.brightpassFBO);

    this.blur(this.brightpassFBO, this.blurFBO1, vec2.fromValues(1.0, 0));
    this.blur(this.blurFBO1, this.blurFBO2, vec2.fromValues(0, 1.0));

    // Ping-pong and grow the spread
    for (let i = 1; i < this.bloomIterations; i++) {
      let spread = 1.0 + (i);

      this.blur(this.blurFBO2, this.blurFBO1, vec2.fromValues(spread, 0));
      this.blur(this.blurFBO1, this.blurFBO2, vec2.fromValues(0, spread));
    }

    this.composite(this.sceneFBO, this.blurFBO2);
  }
};

export default OpenGLRenderer;
