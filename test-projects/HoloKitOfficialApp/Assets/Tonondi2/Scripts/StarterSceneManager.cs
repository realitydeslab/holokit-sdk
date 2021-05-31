using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;
using UnityEngine.XR.ARFoundation;

public class StarterSceneManager : MonoBehaviour
{
    [SerializeField] private GameObject boid;
    [SerializeField] private GameObject triggerBall;
    [SerializeField] private GameObject Hand;

    public GameObject startVfx1;
    public GameObject startVfx2;

    public static Vector3 m_CameraToCenterEyeOffset;

    private Camera arCamera;

    private GameObject triggerBallVfx;

    private bool isGameStarted = false;

    private bool isBoidDisappeared = false;

    [SerializeField] private GameObject treePrefab;
    private float lastSpawnTime = 0f;
    private float intervalTime = 2f;
    private int maxTreeNum = 1;

    private bool isSpawningTrees = false;

    [DllImport("__Internal")]
    public static extern int UnityHoloKit_GetRenderingMode();

    [DllImport("__Internal")]
    public static extern float UnityHoloKit_GetCameraToCenterEyeOffsetX();

    [DllImport("__Internal")]
    public static extern float UnityHoloKit_GetCameraToCenterEyeOffsetY();

    [DllImport("__Internal")]
    public static extern float UnityHoloKit_GetCameraToCenterEyeOffsetZ();

    [DllImport("__Internal")]
    public static extern void UnityHoloKit_SetWorldOrigin(float[] position, float[] rotation);

    private void OnEnable()
    {
        BoidMovementController.OnTriggerBallDisplayed += DisplayTriggerBall;

        int renderingMode = UnityHoloKit_GetRenderingMode();
        if (renderingMode != 2)
        {
            Camera.main.GetComponent<ARCameraBackground>().enabled = true;
        }

        float offsetX = UnityHoloKit_GetCameraToCenterEyeOffsetX();
        float offsetY = UnityHoloKit_GetCameraToCenterEyeOffsetY();
        float offsetZ = UnityHoloKit_GetCameraToCenterEyeOffsetZ();
        m_CameraToCenterEyeOffset = new Vector3(offsetX, offsetY, -offsetZ);
        Debug.Log($"Camera to center eye offset: {m_CameraToCenterEyeOffset.ToString("F4")}");

        arCamera = Camera.main;
    }

    private void OnDisable()
    {
        BoidMovementController.OnTriggerBallDisplayed -= DisplayTriggerBall;
    }

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (!isGameStarted)
        {
            if (startVfx1.GetComponent<DisturbStripe>().ScaleForBoom > 0.999f)
            {
                startVfx1.SetActive(false);
                //startVfx2.SetActive(false);
                startVfx2.GetComponent<DisturbStripe>().enabled = false;
                isGameStarted = true;
                

                Vector3 newWorldOriginPosition = arCamera.transform.position + arCamera.transform.TransformVector(m_CameraToCenterEyeOffset);

                Vector3 cameraRotationInEuler = arCamera.transform.rotation.eulerAngles;
                Quaternion newWorldOriginRotation = Quaternion.Euler(0.0f, cameraRotationInEuler.y, 0.0f);
                float[] position = { newWorldOriginPosition.x, newWorldOriginPosition.y, newWorldOriginPosition.z };
                float[] rotation = { newWorldOriginRotation.x, newWorldOriginRotation.y, newWorldOriginRotation.z, newWorldOriginRotation.w };
                UnityHoloKit_SetWorldOrigin(position, rotation);
                boid.SetActive(true);
            }
        }

        if (isGameStarted && !isBoidDisappeared)
        {
            if (triggerBall.transform.GetChild(0).GetComponent<DisturbStripe>().ScaleForBoom > 0.99f)
            {
                boid.SetActive(false);
                isBoidDisappeared = true;
                // TODO: the entry point of the next scene
                isSpawningTrees = true;
            }
            lastSpawnTime = Time.time;
        }

        if (isSpawningTrees && this.transform.childCount < maxTreeNum)
        {

            Vector3 spawningPositoin = RayCastPosition();
            if (!spawningPositoin.Equals(Vector3.zero) && (Time.time - lastSpawnTime) > intervalTime)
            {
                GameObject go = Instantiate(treePrefab) as GameObject;
                go.transform.parent = this.transform;
                go.transform.position = new Vector3(0,-1.5f,1);
                //float a = Random.Range(0.03f, 0.06f);
                //go.transform.localScale = new Vector3(a,a,a);
                go.GetComponent<GlowingTree>().Hand = Hand.transform;
                lastSpawnTime = Time.time;
            }
        }
    }

    private void DisplayTriggerBall()
    {
        Debug.Log("Trigger ball displayed.");

        boid.GetComponent<BoidMovementModeController>().ChangeMovementMode();
        //boid.SetActive(false);
        triggerBall.SetActive(true);
    }

    private Vector3 RayCastPosition()
    {
        float radius = 4f;
        Vector3 direction = new Vector3(Random.Range(-1f, 1f), 3f, Random.Range(-1f, 1f)).normalized;
        Vector3 ceilPosition = direction * radius;
        RaycastHit hit;
        if(Physics.Raycast(ceilPosition, new Vector3(0f, -1f, 0f), out hit))
        {
            if (hit.transform.tag == "Meshing")
            {
                return hit.point;
            }
            else
            {
                return Vector3.zero;
            }
        }
        return Vector3.zero;
    }
}
