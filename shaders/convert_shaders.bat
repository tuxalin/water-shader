
@ECHO OFF >NUL

if "%~1" == "" (set WORK_PATH=%cd%) else (set WORK_PATH=%~1)

echo.
echo "Converting shaders in: "%WORK_PATH%
echo.

 %VULKAN_SDK%/Bin32/glslangValidator.exe -S vert -e vert -o glsl/water.vert.spv -V -D hlsl/water.fx
 %VULKAN_SDK%/Bin32/glslangValidator.exe -S frag -e frag -o glsl/water.frag.spv -V -D hlsl/water.fx
