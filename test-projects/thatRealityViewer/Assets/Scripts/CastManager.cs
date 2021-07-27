using UnityEngine;

[RequireComponent(typeof(Camera))]
public class CastManager : MonoBehaviour
{
    [SerializeField] private RenderTexture m_SecondCameraRenderTexture;

    private Material copyMaterial;

    private void Start()
    {
        Shader shader = Shader.Find("Hidden/BlitCopy");
        copyMaterial = new Material(shader);
        if (copyMaterial != null)
        {
            Debug.Log("fuck fuck fuck");
        }

        m_SecondCameraRenderTexture.width = Display.main.renderingWidth;
        m_SecondCameraRenderTexture.height = Display.main.renderingHeight;
        Debug.Log($"Width: {m_SecondCameraRenderTexture.width}");
        Debug.Log($"Height: {m_SecondCameraRenderTexture.height}");
    }

    private void Update()
    {
        

        if (Display.displays.Length > 1)
        {
            Display secondDisplay = Display.displays[1];
            secondDisplay.SetRenderingResolution(Display.main.renderingWidth, Display.main.renderingHeight);
            Graphics.SetRenderTarget(secondDisplay.colorBuffer, secondDisplay.depthBuffer);
            Graphics.Blit(m_SecondCameraRenderTexture, copyMaterial);
        }
    }
}
