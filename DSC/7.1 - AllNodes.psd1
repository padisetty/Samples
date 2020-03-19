@{
    AllNodes = (
        @{  NodeName = "localhost"; 
            Role = "Worker"; 
            Path = "calc.exe";
         },
        @{  NodeName = "Server1"; 
            Role = "Web"; 
            SourceRoot = "\\Server106\source\presentation\"; 
            Version = "1.0"; 
            WebDirectory = "c:\inetpub\wwwroot\"; 
            RecurseValue = $true
         },
        @{   NodeName = "Server778"; 
            Role = "SQL"; 
            SQLRole = "Slave";
            SourceRoot = "\\Server145\SQLSource\";
            ConfigurationFile = "SlaveDB.ini"; 
            Version = "2012";
         },
        @{
            NodeName = "*";
            EnvironmentName = "Production";
         }
    )
}