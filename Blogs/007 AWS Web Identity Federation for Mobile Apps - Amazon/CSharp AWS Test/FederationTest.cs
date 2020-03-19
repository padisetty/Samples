//--------------------------------------------------------------------------------------------
//   Copyright 2014 Sivaprasad Padisetty
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//--------------------------------------------------------------------------------------------

using System;
using System.Configuration;

using Amazon.S3;
using Amazon.SecurityToken.Model;
using Amazon.IdentityManagement;
using Amazon.IdentityManagement.Model;

namespace AWS_CSharp_Test
{
    class FederationTest
    {
        public static void Test(string identityProvider)
        {
            // Login with credentials to create the role
            // credentials are defined in app.config
            var iamClient = new AmazonIdentityManagementServiceClient();
            string providerURL = null,
                   providerAppIdName = null,
                   providerUserIdName = null,
                   providerAppId = null;


            switch (identityProvider)
            {
                case "Facebook":
                    providerURL = "graph.facebook.com";
                    providerAppIdName = "app_id";
                    providerUserIdName = "id";
                    break;
                case "Google":
                    providerURL = "accounts.google.com";
                    providerAppIdName = "aud";
                    providerUserIdName = "sub";
                    break;
                case "Amazon":
                    providerURL = "www.amazon.com";
                    providerAppIdName = "app_id";
                    providerUserIdName = "user_id";
                    break;
            }

            //identity provider specific AppId is loaded from app.config (e.g)
            //  FacebookProviderAppId. GoogleProviderAppId, AmazonProviderAppId
            providerAppId = ConfigurationManager.AppSettings[identityProvider + 
                                                               "ProviderAppId"];

            // Since the string is passed to String.Format, '{' & '}' has to be escaped.
            // Policy document specifies who can invoke AssumeRoleWithWebIdentity
            string trustPolicyTemplate = @"{{
                  ""Version"": ""2012-10-17"",
                  ""Statement"": [
                        {{
                              ""Effect"": ""Allow"",
                              ""Principal"": {{ ""Federated"": ""{1}"" }},
                              ""Action"": ""sts:AssumeRoleWithWebIdentity"",
                              ""Condition"": {{
                                    ""StringEquals"": {{""{1}:{2}"": ""{3}""}}
                              }}
                        }}
                  ]
                }}";

            // Defines what permissions to grant when AssumeRoleWithWebIdentity is called
            string accessPolicyTemplate = @"{{
                    ""Version"": ""2012-10-17"",
                    ""Statement"": [
                    {{
                        ""Effect"":""Allow"",
                        ""Action"":[""s3:GetObject"", ""s3:PutObject"", ""s3:DeleteObject""],
                        ""Resource"": [
                                ""arn:aws:s3:::federationtestbucket/{0}/${{{1}:{4}}}"",
                                ""arn:aws:s3:::federationtestbucket/{0}/${{{1}:{4}}}/*""
                        ]
                    }}
                    ]
                }}";

            // Create Trust policy
            CreateRoleRequest createRoleRequest = new CreateRoleRequest
            {
                RoleName = "federationtestrole",
                AssumeRolePolicyDocument = string.Format(trustPolicyTemplate, 
                                                            identityProvider, 
                                                            providerURL, 
                                                            providerAppIdName, 
                                                            providerAppId)
            };
            Console.WriteLine("\nTrust Policy Document:\n{0}\n", 
                createRoleRequest.AssumeRolePolicyDocument);
            CreateRoleResponse createRoleResponse = iamClient.CreateRole(createRoleRequest);

            // Create Access policy (Permissions)
            PutRolePolicyRequest putRolePolicyRequest = new PutRolePolicyRequest
            {
                PolicyName = "federationtestrole-rolepolicy",
                RoleName = "federationtestrole",
                PolicyDocument = string.Format(accessPolicyTemplate, 
                                                identityProvider, 
                                                providerURL, 
                                                providerAppIdName, 
                                                providerAppId, 
                                                providerUserIdName)

            };
            Console.WriteLine("\nAccess Policy Document (Permissions):\n{0}\n", 
                                                putRolePolicyRequest.PolicyDocument);
            PutRolePolicyResponse putRolePolicyResponse = iamClient.PutRolePolicy(
                                                               putRolePolicyRequest);

            // Sleep for the policy to replicate
            System.Threading.Thread.Sleep(5000);
            AmazonS3Config config = new AmazonS3Config
            {
                ServiceURL = "s3.amazonaws.com",
                RegionEndpoint = Amazon.RegionEndpoint.USEast1
            };

            Federation federationTest = new Federation();
            AssumeRoleWithWebIdentityResponse assumeRoleWithWebIdentityResponse = null;

            switch (identityProvider)
            {
                case "Facebook":
                    assumeRoleWithWebIdentityResponse = 
                        federationTest.GetTemporaryCredentialUsingFacebook(
                                providerAppId,
                                createRoleResponse.Role.Arn);
                    break;
                case "Google":
                    assumeRoleWithWebIdentityResponse = 
                        federationTest.GetTemporaryCredentialUsingGoogle(
                                providerAppId,
                                createRoleResponse.Role.Arn);

                    //Uncomment to perform two step process
                    //assumeRoleWithWebIdentityResponse = 
                    //    federationTest.GetTemporaryCredentialUsingGoogle(
                    //            providerAppId,
                    //            ConfigurationManager.AppSettings["GoogleProviderAppIdSecret"],
                    //            createRoleResponse.Role.Arn);
                    break;
                case "Amazon":
                    assumeRoleWithWebIdentityResponse = 
                        federationTest.GetTemporaryCredentialUsingAmazon(
                                ConfigurationManager.AppSettings["AmazonProviderClientId"],
                                createRoleResponse.Role.Arn);
                    break;
            }

            S3Test s3Test = new S3Test();
            s3Test.CreateS3Bucket("federationtestbucket",
                identityProvider + "/" + 
                assumeRoleWithWebIdentityResponse.SubjectFromWebIdentityToken,
                assumeRoleWithWebIdentityResponse.Credentials, config);

            DeleteRolePolicyResponse deleteRolePolicyResponse = 
                iamClient.DeleteRolePolicy(new DeleteRolePolicyRequest
                {
                    PolicyName = "federationtestrole-rolepolicy",
                    RoleName = "federationtestrole"
                });

            DeleteRoleResponse deleteRoleResponse = 
                iamClient.DeleteRole(new DeleteRoleRequest
                {
                    RoleName = "federationtestrole"
                });
        }
    }
}
