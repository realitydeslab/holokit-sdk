using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ZoomBlur : VolumeComponent, IPostProcessComponent
{
    [Range(0f,100f), Tooltip("增强模糊效果")]
    public FloatParameter focusPower = new FloatParameter(0f);

    [Range(0, 10), Tooltip("越大效果越好，效率越低")]
    public IntParameter focusDetail = new IntParameter(5);

    public Vector2Parameter foucusScreenPosition = new Vector2Parameter(Vector2.zero);

    public IntParameter referenceResolutionX = new IntParameter(1334);

    public Shader m_Shader;

    public bool IsActive() => focusPower.value > 0f;
    public bool IsTileCompatible() => false;
}
