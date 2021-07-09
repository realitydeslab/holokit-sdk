using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class HittingRippleRoom : MonoBehaviour
{
    private static HittingRippleRoom _instance;

    public static HittingRippleRoom Instance { get { return _instance; } }

    private Vector3 hitPoint;

    List<float> amp = new List<float>();
    [SerializeField] private float fadeSpeed = .5f;

    private void Awake()
    {
        if (_instance != null && _instance != this)
        {
            Destroy(this.gameObject);
        }
        else
        {
            _instance = this;
        }
    }

    // Start is called before the first frame update
    void Start()
    {
        for (int i = 0; i < 3; i++)
        {
            amp.Add(0);

        }
    }

    // Update is called once per frame
    void Update()
    {

        for (int i = 0; i < amp.Count; i++)
        {
            if (amp[i] > 0)
            {
                amp[i] -= fadeSpeed * Time.deltaTime;
                Shader.SetGlobalFloat("_amp" +i, amp[i]);
            }
            else
            {
                amp[i] = 0;
            }
        }
    }

    void HitOnTheMesh()
    {
        for (int i = 0; i < amp.Count; i++)
        {
            if (amp[i] == 0)
            {
                amp[i] = 1;
                Shader.SetGlobalVector("_hitPosition" +i , hitPoint);
                break;
            }
            else { }
        }
    }

    public void SetHitPoint(Vector3 point)
    {
        Debug.Log("fucking1231241233");
        hitPoint = point;
        HitOnTheMesh();
    }
}
