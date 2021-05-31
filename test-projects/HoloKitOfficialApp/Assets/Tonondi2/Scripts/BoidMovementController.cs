using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class BoidMovementController : MonoBehaviour
{
    //[SerializeField] private Transform m_LeftHand;
    //[SerializeField] private Transform Obstacle;

    [SerializeField] private GameObject m_Target;

    [SerializeField] private GameObject m_BoidTrajectoryPoints;

    private List<Transform> m_Points = new List<Transform>();

    private int m_NextPointIndex = 0;

    [SerializeField] private float speed = 0.1f;

    private const float k_MinDistance = 0.1f;

    public delegate void DisplayTriggerBall();
    public static event DisplayTriggerBall OnTriggerBallDisplayed;

    // Start is called before the first frame update
    void Start()
    {
        for (int i = 0; i < m_BoidTrajectoryPoints.transform.childCount; i++)
        {
            m_Points.Add(m_BoidTrajectoryPoints.transform.GetChild(i));
        }

        m_Target.transform.position = m_Points[m_NextPointIndex++].transform.position;
    }

    // Update is called once per frame
    void Update()
    {
        if (Vector3.Distance(m_Target.transform.position, m_Points[m_NextPointIndex].position) > k_MinDistance)
        {
            m_Target.GetComponent<Rigidbody>().velocity = (m_Points[m_NextPointIndex].transform.position - m_Target.transform.position).normalized * speed;
        }
        else
        {
            if (m_NextPointIndex == m_BoidTrajectoryPoints.transform.childCount - 1)
            {
                m_NextPointIndex = 0;
                // The first round has finished.
                OnTriggerBallDisplayed();
            }
            else
            {
                m_NextPointIndex++;
            }       
        }

        //Obstacle.position = m_LeftHand.position;
    }
}
