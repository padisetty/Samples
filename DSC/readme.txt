1. Sample scripts are designed to run locally. DSC has two distinct phases. 
    a) Generate the MOF file (declarative document.) 
    b) Then apply the MOF either to a local node or to a remote node. 
   The samples are designed to run locally.
 
2. In real world it is preferred to author the config in a separate file.
    generating the MOF and application is done from a different file. 
    The script that generates the MOF & applies is like a driver file
    
3. The scripts are designed to introduce the concepts incrementally 