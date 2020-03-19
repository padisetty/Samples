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

using Amazon.S3;
using Amazon.S3.Model;
using Amazon.SecurityToken.Model;

namespace AWS_CSharp_Test
{
    class S3Test
    {
        public void CreateS3Bucket(string bucketName, string key, Credentials credentials, AmazonS3Config config)
        {
            var s3Client = new AmazonS3Client(credentials.AccessKeyId, credentials.SecretAccessKey, credentials.SessionToken, config);

            string content = "Hello World2!";

            // Put an object in the user's "folder".
            s3Client.PutObject(new PutObjectRequest
            {
                BucketName = bucketName,
                Key = key,
                ContentBody = content
            });

            Console.WriteLine("Updated key={0} with content={1}", key, content);
        }
    }
}
