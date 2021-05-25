using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class TransportationController : MonoBehaviour
{
    [SerializeField] private string sceneName;

    private bool isTransitted = false;

    private void OnTriggerEnter(Collider other)
    {
        if (!isTransitted)
        {
            Debug.Log("Transportation!");
            if (other.tag.Equals("LandmarkLeft") || other.tag.Equals("LandmarkRight"))
            {
                SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
            }
            isTransitted = true;
        }
    }
}
