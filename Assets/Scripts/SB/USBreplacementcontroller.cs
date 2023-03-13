using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class USBreplacementcontroller : MonoBehaviour
{

    public Shader m_ReplacementShader;


    private void OnEnable()
    {
        if (m_ReplacementShader != null)
        {
            GetComponent<Camera>().SetReplacementShader(m_ReplacementShader, "RenderType");
        }
    }

    private void OnDisable()
    {
        GetComponent<Camera>().ResetReplacementShader();
    }
    void Start()
    {
        
    }

    void Update()
    {
        
    }
}
