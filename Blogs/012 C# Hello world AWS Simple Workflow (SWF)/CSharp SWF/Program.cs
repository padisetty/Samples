//--------------------------------------------------------------------------------------------
//  Copyright 2014 Sivaprasad Padisetty
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//--------------------------------------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Linq;
using Amazon;
using Amazon.SimpleWorkflow;
using Amazon.SimpleWorkflow.Model;

namespace swf
{
  class Program
  {
    static string domainName = "HelloWorldDomain";
    static IAmazonSimpleWorkflow swfClient = 
                AWSClientFactory.CreateAmazonSimpleWorkflowClient();

    public static void Main(string[] args)
    {
      string workflowName = "HelloWorld Workflow";
  
      // Setup
      RegisterDomain();
      RegisterActivity("Activity1A", "Activity1");
      RegisterActivity("Activity1B", "Activity1");
      RegisterActivity("Activity2", "Activity2");
      RegisterWorkflow(workflowName);
     
      // Launch workers to service Activity1A and Activity1B
      //  This is acheived by sharing same tasklist name (i.e.) "Activity1"
      Task.Run(() => Worker("Activity1"));
      Task.Run(() => Worker("Activity1"));

      // Launch Workers for Activity2
      Task.Run(() => Worker("Activity2"));
      Task.Run(() => Worker("Activity2"));
      
      // Start the Deciders, which defines the structure/flow of Workflow
      Task.Run(() => Decider());

      //Start the workflow
      Task.Run(() => StartWorkflow(workflowName));

      Console.Read();
    }

    static void RegisterDomain()
    {
      // Register if the domain is not already registered.
      var listDomainRequest = new ListDomainsRequest()
      {
        RegistrationStatus = RegistrationStatus.REGISTERED
      };

      if (swfClient.ListDomains(listDomainRequest).DomainInfos.Infos.FirstOrDefault(
                                                x => x.Name == domainName) == null)
      {
        RegisterDomainRequest request = new RegisterDomainRequest()
        {
          Name = domainName,
          Description = "Hello World Demo",
          WorkflowExecutionRetentionPeriodInDays = "1"
        };

        Console.WriteLine("Setup: Created Domain - " + domainName);
        swfClient.RegisterDomain(request);
      }
    }

    static void RegisterActivity (string name, string tasklistName)
    {
      // Register activities if it is not already registered
      var listActivityRequest = new ListActivityTypesRequest()
      {
        Domain = domainName,
        Name = name,
        RegistrationStatus = RegistrationStatus.REGISTERED
      };

      if (swfClient.ListActivityTypes(listActivityRequest).ActivityTypeInfos.TypeInfos.FirstOrDefault(
                                    x => x.ActivityType.Version == "2.0") == null)
      {
        RegisterActivityTypeRequest request = new RegisterActivityTypeRequest()
        {
          Name = name,
          Domain = domainName,
          Description = "Hello World Activities",
          Version = "2.0",
          DefaultTaskList = new TaskList() { Name = tasklistName },//Worker poll based on this
          DefaultTaskScheduleToCloseTimeout = "300",
          DefaultTaskScheduleToStartTimeout = "150",
          DefaultTaskStartToCloseTimeout = "450",
          DefaultTaskHeartbeatTimeout = "NONE",
        };
        swfClient.RegisterActivityType(request);
        Console.WriteLine("Setup: Created Activity Name - " + request.Name);
      }
    }

    static void RegisterWorkflow(string name)
    {
      // Register workflow type if not already registered
      var listWorkflowRequest = new ListWorkflowTypesRequest()
      {
        Name = name,
        Domain = domainName,
        RegistrationStatus = RegistrationStatus.REGISTERED
      };
      if (swfClient.ListWorkflowTypes(listWorkflowRequest).WorkflowTypeInfos.TypeInfos.FirstOrDefault (
                                      x => x.WorkflowType.Version == "2.0") == null)
      {
        RegisterWorkflowTypeRequest request = new RegisterWorkflowTypeRequest()
        {
          DefaultChildPolicy = ChildPolicy.TERMINATE,
          DefaultExecutionStartToCloseTimeout = "300",
          DefaultTaskList = new TaskList()
          {
            Name = "HelloWorld" // Decider need to poll for this task
          },
          DefaultTaskStartToCloseTimeout = "150",
          Domain = domainName,
          Name = name,
          Version = "2.0"
        };

        swfClient.RegisterWorkflowType(request);

        Console.WriteLine("Setup: Registerd Workflow Name - " + request.Name);
      }
    }

    static void StartWorkflow (string name)
    {
      IAmazonSimpleWorkflow swfClient = AWSClientFactory.CreateAmazonSimpleWorkflowClient();
      string workflowID = "Hello World WorkflowID - " + DateTime.Now.Ticks.ToString();
      swfClient.StartWorkflowExecution(new StartWorkflowExecutionRequest()
      {
        Input = "{\"inputparam1\":\"value1\"}", // Serialize input to a string

        WorkflowId = workflowID,
        Domain = domainName,
        WorkflowType = new WorkflowType()
        {
          Name = name,
          Version = "2.0"
        }
      });
      Console.WriteLine("Setup: Workflow Instance created ID=" + workflowID);
    }

    static void Worker(string tasklistName)
    {
      string prefix = string.Format("Worker{0}:{1:x} ", tasklistName, 
                            System.Threading.Thread.CurrentThread.ManagedThreadId);
      while (true)
      {
        Console.WriteLine(prefix + ": Polling for activity task ...");
        PollForActivityTaskRequest pollForActivityTaskRequest = 
            new PollForActivityTaskRequest() {
                                      Domain = domainName,
                                      TaskList = new TaskList()
                                      {
                                          // Poll only the tasks assigned to me
                                        Name = tasklistName
                                      }
                                };
        PollForActivityTaskResponse pollForActivityTaskResponse = 
                        swfClient.PollForActivityTask(pollForActivityTaskRequest);

        RespondActivityTaskCompletedRequest respondActivityTaskCompletedRequest = 
                    new RespondActivityTaskCompletedRequest() {
                              Result = "{\"activityResult1\":\"Result Value1\"}",
                              TaskToken = pollForActivityTaskResponse.ActivityTask.TaskToken
                            };
        if (pollForActivityTaskResponse.ActivityTask.ActivityId == null)
        {
          Console.WriteLine(prefix + ": NULL");
        }
        else
        {
          RespondActivityTaskCompletedResponse respondActivityTaskCompletedResponse = 
              swfClient.RespondActivityTaskCompleted(respondActivityTaskCompletedRequest);
          Console.WriteLine(prefix + ": Activity task completed. ActivityId - " + 
              pollForActivityTaskResponse.ActivityTask.ActivityId);
        }
      }
    }

    static void ScheduleActivity(string name, List<Decision> decisions)
    {
      Decision decision = new Decision()
      {
        DecisionType = DecisionType.ScheduleActivityTask,
        ScheduleActivityTaskDecisionAttributes =  // Uses DefaultTaskList
            new ScheduleActivityTaskDecisionAttributes() {
                      ActivityType = new ActivityType()
                      {
                        Name = name,
                        Version = "2.0"
                      },
                      ActivityId = name + "-" + System.Guid.NewGuid().ToString(),
                      Input = "{\"activityInput1\":\"value1\"}"
                    }
      };
      Console.WriteLine("Decider: ActivityId=" + 
                    decision.ScheduleActivityTaskDecisionAttributes.ActivityId);
      decisions.Add(decision);
    }

    // Simple logic
    //  Creates four activities at the begining
    //  Waits for them to complete and completes the workflow
    static void Decider()
    {
      int activityCount = 0; // This refers to total number of activities per workflow
      IAmazonSimpleWorkflow swfClient = AWSClientFactory.CreateAmazonSimpleWorkflowClient();
      while (true)
      {
        Console.WriteLine("Decider: Polling for decision task ...");
        PollForDecisionTaskRequest request = new PollForDecisionTaskRequest()
                              {
                                Domain = domainName,
                                TaskList = new TaskList() {Name = "HelloWorld"}
                              };

        PollForDecisionTaskResponse response = swfClient.PollForDecisionTask(request);
        if (response.DecisionTask.TaskToken == null)
        {
          Console.WriteLine("Decider: NULL");
          continue;
        }

        int completedActivityTaskCount = 0, totalActivityTaskCount = 0;
        foreach (HistoryEvent e in response.DecisionTask.Events)
        {
          Console.WriteLine("Decider: EventType - " + e.EventType + 
              ", EventId - " + e.EventId);
          if (e.EventType == "ActivityTaskCompleted")
            completedActivityTaskCount++;
          if (e.EventType.Value.StartsWith("Activity"))
            totalActivityTaskCount++;
        }
        Console.WriteLine(".... completedCount=" + completedActivityTaskCount);

        List<Decision> decisions = new List<Decision>();
        if (totalActivityTaskCount == 0) // Create this only at the begining
        {
          ScheduleActivity("Activity1A", decisions);
          ScheduleActivity("Activity1B", decisions);
          ScheduleActivity("Activity2", decisions);
          ScheduleActivity("Activity2", decisions);
          activityCount = 4;
        }
        else if (completedActivityTaskCount == activityCount)
        {
          Decision decision = new Decision()
          {
            DecisionType = DecisionType.CompleteWorkflowExecution,
            CompleteWorkflowExecutionDecisionAttributes = 
                new CompleteWorkflowExecutionDecisionAttributes {
                          Result = "{\"Result\":\"WF Complete!\"}"
                        }
          };
          decisions.Add(decision);

          Console.WriteLine("Decider: WORKFLOW COMPLETE!!!!!!!!!!!!!!!!!!!!!!");
        }
        RespondDecisionTaskCompletedRequest respondDecisionTaskCompletedRequest = 
            new RespondDecisionTaskCompletedRequest() {
                      Decisions = decisions,
                      TaskToken = response.DecisionTask.TaskToken
                    };
        swfClient.RespondDecisionTaskCompleted(respondDecisionTaskCompletedRequest);
      }
    }
  }
}