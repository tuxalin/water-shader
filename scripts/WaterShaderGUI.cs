using UnityEngine;
using UnityEditor;
using System;
using System.Collections.Generic;

public class WaterShaderGUI : ShaderGUI
{
    private string[] displacementProps = new string[] { "_HeightTexture", "_HeightIntensity", "_WaveTiling", "_WaveAmplitudeFactor", "_WaveSteepness", "_WaveAmplitude" };
    private string[] meanSkyProps = new string[] { "_RadianceFactor" };
    private string[] foamProps = new string[] { "_ShoreTexture", "_FoamTexture", "_FoamTiling", "_FoamNoise", "_FoamSpeed", "_FoamIntensity" };

    private void CheckFeature(Material targetMat, MaterialProperty[] materialProperties, string toggleName, string featureName, string[] properties, HashSet<string> disabledProperties)
    {
        bool isEnabled = Array.IndexOf(targetMat.shaderKeywords, featureName) != -1;

        MaterialProperty toggle = ShaderGUI.FindProperty(toggleName, materialProperties);
        if (toggle.floatValue == 0 && isEnabled == false)
        {
            foreach (string name in properties)
            {
                disabledProperties.Add(name);
            }
        }
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material targetMat = materialEditor.target as Material;

        HashSet<string> disabledProperties = new HashSet<string>();
        CheckFeature(targetMat, properties, "_UseDisplacement", "USE_DISPLACEMENT", displacementProps, disabledProperties);
        CheckFeature(targetMat, properties, "_UseMeanSky", "USE_MEAN_SKY_RADIANCE", meanSkyProps, disabledProperties);
        CheckFeature(targetMat, properties, "_UseFoam", "USE_FOAM", foamProps, disabledProperties);

        // show only visible properties based on enabled features
        foreach (MaterialProperty property in properties)
        {
            if (property.name != "_ReflectionTexture" && !disabledProperties.Contains(property.name))
                materialEditor.ShaderProperty(property, property.displayName);
        }
    }
}
