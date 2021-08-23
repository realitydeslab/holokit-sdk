using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TriggerBallManager : MonoBehaviour
{
    public enum TriggerType
    {
        FR,
        FL,
        BR,
        BL,
        Door,
        Roof
    }

    public TriggerType Type;
    private Animator m_Animator;

    // Start is called before the first frame update
    void Start()
    {
        m_Animator = FindObjectOfType<Animator>();
    }

    // Update is called once per frame
    void Update()
    {

    }

    private void OnTriggerEnter(Collider other)
    {
        Debug.Log("TriggerEnter!!");
        OnTriggerBall(Type);
        transform.GetChild(0).GetComponent<LookAtCamera>().OnTrigger();
    }

    void OnTriggerBall(TriggerType t)
    {
        switch (t)
        {
            case TriggerType.FR:
                if (m_Animator.GetBool("Opened FR"))
                {
                    Debug.Log("Close the FR");
                    m_Animator.SetTrigger("Close FR Door");
                    m_Animator.SetBool("Opened FR", false);

                }
                else
                {
                    Debug.Log("Open the FR");
                    m_Animator.SetTrigger("Open FR Door");
                    m_Animator.SetBool("Opened FR", true);
                }

                break;
            case TriggerType.FL:
                if (m_Animator.GetBool("Opened FL"))
                {
                    m_Animator.SetTrigger("Close FL Door");
                    m_Animator.SetBool("Opened FL", false);
                }
                else
                {
                    m_Animator.SetTrigger("Open FL Door");
                    m_Animator.SetBool("Opened FL", true);
                }
                break;
            case TriggerType.BR:
                if (m_Animator.GetBool("Opened BR"))
                {
                    m_Animator.SetTrigger("Close BR Door");
                    m_Animator.SetBool("Opened BR", false);
                }
                else
                {
                    m_Animator.SetTrigger("Open BR Door");
                    m_Animator.SetBool("Opened BR", true);
                }
                break;
            case TriggerType.BL:
                if (m_Animator.GetBool("Opened BL"))
                {
                    m_Animator.SetBool("Opened BL", false);
                    m_Animator.SetTrigger("Close BL Door");
                }
                else
                {
                    m_Animator.SetBool("Opened BL", true);
                    m_Animator.SetTrigger("Open BL Door");
                }

                break;
            case TriggerType.Door:
                if (m_Animator.GetBool("Opened Door"))
                {
                    m_Animator.SetBool("Opened Door", false);
                    m_Animator.SetTrigger("Close The Door");
                }
                else
                {
                    m_Animator.SetBool("Opened Door", true);
                    m_Animator.SetTrigger("Open The Door");
                }
                break;
            case TriggerType.Roof:
                if (m_Animator.GetBool("Opened Roof"))
                {
                    m_Animator.SetBool("Opened Roof", false);
                    m_Animator.SetTrigger("Close The Roof");
                }
                else
                {
                    m_Animator.SetBool("Opened Roof", true);
                    m_Animator.SetTrigger("Open The Roof");
                }

                break;
        }
    }
}
