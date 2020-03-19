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
using System.Text;
using System.Net;
using System.Windows.Forms;
using System.Web;
using System.Collections.Specialized;

using Amazon.SecurityToken;
using Amazon.SecurityToken.Model;
using Amazon.Runtime;
using Newtonsoft.Json;

namespace AWS_CSharp_Test
{
    class Federation
    {
        class MyWebBrowser : WebBrowser
        {
            public string CapturedUrl;
            string token;
            public MyWebBrowser(string token)
            {
                this.token = token + "=";
            }

            protected override void OnDocumentCompleted(
                WebBrowserDocumentCompletedEventArgs e)
            {
                base.OnDocumentCompleted(e);
                string st = e.Url.ToString();
                if (st.Contains(token))
                {
                    // hack, closing the form here does not work always.
                    this.Navigate("about:blank"); 
                    this.CapturedUrl = st;
                    Console.WriteLine("Captured: {0}", st);
                }
                else if (st == "about:blank")
                {
                    ((Form)this.Parent).Close();
                }
            }
        }

        string GetToken(string token, string url)
        {
            Form f = new Form();
            MyWebBrowser wb = new MyWebBrowser(token);
            wb.Dock = DockStyle.Fill;
            f.Controls.Add(wb);
            wb.Navigate(url);
            f.WindowState = FormWindowState.Maximized;
            f.ShowDialog();

            string st = wb.CapturedUrl;
            f.Dispose();

            if (st == null)
                throw new Exception("Oops! Error getting the token");

            int index = st.IndexOfAny(new char[] { '?', '#' });
            st = index < 0 ? "" : st.Substring(index + 1);
            NameValueCollection pairs = HttpUtility.ParseQueryString(st);

            string tokenValue = pairs[token];
            Console.WriteLine("TOKEN={0}, Value={1}", token, tokenValue);
            return tokenValue;
        }

        AssumeRoleWithWebIdentityResponse GetAssumeRoleWithWebIdentityResponse(
            AssumeRoleWithWebIdentityRequest assumeRoleWithWebIdentityRequest)
        {
            // Start with Anonymous AWS Credentials and get temporary credentials.
            var stsClient = new AmazonSecurityTokenServiceClient(
                                    new AnonymousAWSCredentials());
            assumeRoleWithWebIdentityRequest.DurationSeconds = 3600;
            assumeRoleWithWebIdentityRequest.RoleSessionName = "MySession";
            return stsClient.AssumeRoleWithWebIdentity(
                                    assumeRoleWithWebIdentityRequest);
        }

        // client_id of the google app
        // role - ARN for the role to assume
        [STAThread]
        public AssumeRoleWithWebIdentityResponse GetTemporaryCredentialUsingGoogle(
            string client_id, 
            string role)
        {
            string query = "https://accounts.google.com/o/oauth2/auth?" +
                            string.Format("client_id={0}&", client_id) +
                            "response_type=id_token&" +
                            "scope=email%20profile&" +
                            "redirect_uri=http://www.padisetty.com";

            AssumeRoleWithWebIdentityRequest assumeRoleWithWebIdentityRequest = 
                new AssumeRoleWithWebIdentityRequest ()
                {
                    WebIdentityToken = GetToken ("id_token", query),
                    RoleArn = role
                };
            return GetAssumeRoleWithWebIdentityResponse(
                assumeRoleWithWebIdentityRequest);
        }


        // Two Step process
        // client_id of the google app
        // client_secret of the google app
        // role - ARN for the role to assume
        // For demo purpose both steps are performed in the same function
        //   You should do the second step at the server side.
        [STAThread]
        public AssumeRoleWithWebIdentityResponse GetTemporaryCredentialUsingGoogle2(
            string client_id, 
            string client_secret, 
            string role)
        {
            string query = "https://accounts.google.com/o/oauth2/auth?" +
                            string.Format("client_id={0}&", client_id) +
                            "response_type=code&" +
                            "scope=email%20profile&" +
                            "redirect_uri=http://www.padisetty.com";

            string id_token = null;
            using (var wc = new WebClient())
            {
                var data = new NameValueCollection();

                data["code"] = GetToken("code", query);
                data["client_id"] = client_id;
                data["client_secret"] = client_secret;
                data["redirect_uri"] = "http://www.padisetty.com";
                data["grant_type"] = "authorization_code";

                var response = wc.UploadValues(
                    "https://accounts.google.com/o/oauth2/token", 
                    "POST", data);

                string responsebody = Encoding.UTF8.GetString(response);

                dynamic result = JsonConvert.DeserializeObject(responsebody);

                id_token = result.id_token;
            }

            AssumeRoleWithWebIdentityRequest assumeRoleWithWebIdentityRequest = 
                new AssumeRoleWithWebIdentityRequest ()
                {
                    WebIdentityToken = id_token,
                    RoleArn = role
                };
            return GetAssumeRoleWithWebIdentityResponse(assumeRoleWithWebIdentityRequest);
        }

        [STAThread]
        public AssumeRoleWithWebIdentityResponse GetTemporaryCredentialUsingAmazon(
            string client_id, 
            string role)
        {
            string query = "https://www.amazon.com/ap/oa?" +
                            string.Format("client_id={0}&", client_id) +
                            "response_type=token&" +
                            "scope=profile&" +
                            "redirect_uri=https://www.google.com";

            AssumeRoleWithWebIdentityRequest assumeRoleWithWebIdentityRequest = 
                new AssumeRoleWithWebIdentityRequest ()
                {
                    ProviderId = "www.amazon.com",
                    WebIdentityToken = GetToken("access_token", query),
                    RoleArn = role
                };
            return GetAssumeRoleWithWebIdentityResponse(
                assumeRoleWithWebIdentityRequest);
        }

        // role - ARN for the role to assume
        // client_id of the Facebook app
        [STAThread]
        public AssumeRoleWithWebIdentityResponse GetTemporaryCredentialUsingFacebook(
            string client_id, 
            string role)
        {
            string query = "https://www.facebook.com/dialog/oauth?" + 
                string.Format ("client_id={0}&", client_id) + 
                "response_type=token&" +
                "redirect_uri=https://www.facebook.com/connect/login_success.html";

            AssumeRoleWithWebIdentityRequest assumeRoleWithWebIdentityRequest = 
                new AssumeRoleWithWebIdentityRequest ()
                {
                    ProviderId = "graph.facebook.com",
                    WebIdentityToken = GetToken("access_token", query),
                    RoleArn = role,
                };

            return GetAssumeRoleWithWebIdentityResponse (assumeRoleWithWebIdentityRequest);
        }
    }
}
