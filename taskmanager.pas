unit TaskManager;

{$mode objfpc}{$H+}

interface

uses
  LCLIntf, Classes, Controls, LMessages, Forms, SysUtils, unixtype, pipes, syncobjs, fgl, ctypes, pthreads;

const
  TM_INVALID_MESSAGE = 0;
  TM_ADD_RESOURCE = 1;
  TM_ADD_TASK = TM_ADD_RESOURCE + 1;
  TM_REMOVE_TASK = TM_ADD_TASK + 1;
  TM_KILL_TASK = TM_REMOVE_TASK + 1;
  TM_FREE_TASK = TM_KILL_TASK + 1;

  TM_ON_TASK_PREPARED = TM_FREE_TASK + 1;
  TM_ON_TASK_START = TM_ON_TASK_PREPARED + 1;
  TM_ON_TASK_FINISH = TM_ON_TASK_START + 1;
  TM_ON_TASK_KILLED = TM_ON_TASK_FINISH + 1;

  TM_CLEAR_TASKS_LIST = TM_ON_TASK_KILLED + 1;
  TM_SET_WORKERS = TM_CLEAR_TASKS_LIST + 1;

  //TM_LOCK_MASSAGE_PROCESS = TM_SET_WORKERS + 1;
  LM_TMSync = LM_USER + $400;

type

  TTaskManager = class;

  { TTMMessage }

  TTMMessage = record
    Message: integer;
    Data: Pointer;
  end;

  PTMMessage = ^TTMMessage;

  { TTMThread }

  TTMThreadSyncRecord = record
    SyncMutex: ppthread_mutex_t;
    SyncCond: ppthread_cond_t;
    Method: TThreadMethod;
  end;
  PTMThreadSyncRecord = ^TTMThreadSyncRecord;

  TTMThread = class
  private
    FFreeOnTerminate: boolean;
    FOnTerminated: TNotifyEvent;
    FTerminated: boolean;
    FPThread: culong;
    FSyncMutex: pthread_mutex_t;
    FSyncCond: pthread_cond_t;
  protected
    procedure Execute; virtual; abstract;
    procedure DoTerminated;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Start;
    procedure Kill;
    procedure Waitfor;
    procedure Terminate;
    procedure Synchronize(AMethod: TThreadMethod);
    property FreeOnTerminate: boolean read FFreeOnTerminate write FFreeOnTerminate;
    property OnTerminated: TNotifyEvent read FOnTerminated write FOnTerminated;
    property Terminated: boolean read FTerminated;
  end;

  { TTMSupportApplication }

  TTMSupportApplication = class(TApplication)
  protected
    procedure LMSyncHandler(var TheMessage: TLMessage); message LM_TMSync;
  end;

  { TPipe }

  TPipe = class
  private
    FInputStream: TInputPipeStream;
    FOutputSteam: TOutputPipeStream;
  public
    constructor Create;
    function AvailableSizeToRead: longint;
    function Read(var Buffer; Count: longint): longint;
    function Write(const Buffer; Count: longint): longint;
  end;

  TResource = class

  end;

  TResourceClass = class of TResource;

  TResourceList = specialize TFPGList<TResource>;
  TResourceClassList = specialize TFPGList<TResourceClass>;

  TTaskState = (tsReady, tsStarting, tsRunning, tsTerminated, tsKilled);

  { TTask }

  TTask = class
  private
    FOwner: TTaskManager;
    FResources: TResourceList;
    FResourcesClass: TResourceClassList;
    FState: TTaskState;
    FWorker: TTMThread;
    procedure Execute;
  protected
    procedure RegisterResource(AResourceClass: TResourceClass);
    function GetResource(AResourceClass: TResourceClass): TResource;
    procedure RequestResources; virtual;
    procedure Run; virtual; abstract;
    procedure PerformBeforeStart; virtual;
    procedure PerformAfterFinish; virtual;
  public
    constructor Create(AOwner: TTaskManager); virtual;
    destructor Destroy; override;
  end;

  TTaskList = specialize TFPGList<TTask>;
  TTaskEvent = procedure(ATask: TTask) of object;

  { TTaskRunner }

  TTaskRunner = class(TTMThread)
  private
    FTask: TTask;
  protected
    procedure Execute; override;
  public
    constructor Create(ATask: TTask);
    property Task: TTask read FTask write FTask;
  end;

  { TTaskManager }

  TTaskManager = class(TTMThread)
  private
    FOnFinish: TNotifyEvent;
    FOnStart: TNotifyEvent;
    FOnTaskError: TTaskEvent;
    FOnTaskFinish: TTaskEvent;
    FOnTaskKilled: TTaskEvent;
    FOnTaskStart: TTaskEvent;

    FPipe: TPipe;
    FTasks: TTaskList;
    FResources: TResourceList;
    FWorkerCount: integer;
    FRunningTasks: integer;


    FFinishEvent: PRTLEvent;
    FProcessControl: TRTLCriticalSection;

    FSyncTask: TTask;
    FSyncMessage: integer;
    procedure DoSyncTaskMessage;

    function GetTask(Index: integer): TTask;
    function GetTaskCount: integer;
    procedure ReleaseTaskResources(ATask: TTask);
    function GetResource(AResourceClass: TResourceClass): TResource;
    function CheckResources(ATask: TTask): boolean;

    function ReadMessage: TTMMessage;
    procedure WriteMessage(AMessage: integer; TheData: Pointer);
    procedure SetWorkerCount(AValue: integer);
    procedure DoKillTask(ATask: TTask);
    procedure DoSetWorkers(TheWorkerCount: integer);
    procedure DoOnTaskFinish(ATask: TTask);
    procedure DoOnTaskKilled(ATask: TTask);
    procedure DoOnTaskPrepared(ATask: TTask);
    procedure DoOnTaskStart(ATask: TTask);

    procedure DoStart;
    procedure DoFinish;

  protected
    procedure Execute; override;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure AddTask(ATask: TTask);
    procedure RemoveTask(ATask: TTask);
    procedure AddResource(AResource: TResource);

    procedure KillTask(ATask: TTask);

    procedure Pause;
    procedure Resume;

    property Tasks[Index: integer]: TTask read GetTask; default;
    property TaskCount: integer read GetTaskCount;

    property WorkerCount: integer read FWorkerCount write SetWorkerCount;

    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    //property OnPause: TNotifyEvent read FOnPause write FOnPause;
    //property OnResume: TNotifyEvent read FOnResume write FOnResume;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;

    property OnTaskFinish: TTaskEvent read FOnTaskFinish write FOnTaskFinish;
    property OnTaskStart: TTaskEvent read FOnTaskStart write FOnTaskStart;
    property OnTaskKilled: TTaskEvent read FOnTaskKilled write FOnTaskKilled;
    property OnTaskError: TTaskEvent read FOnTaskError write FOnTaskError;
  end;

//{ TSyncThread }

//TSyncThread = class(TThread)
//private
//  FSyncTask: TTask;
//  FSyncMessage: integer;
//  FTaskManager: TTaskManager;
//  procedure DoSyncTaskMessage;
//protected
//  procedure Execute; override;
//public
//  constructor Create(AOwner: TTaskManager);
//  procedure Sync;
//end;

implementation

var
  SyncMutex: pthread_mutex_t;

{ TTMThread }

function CallThreadExecute(_para1: pointer): Pointer; cdecl;
var
  aThread: TTMThread;
  dummy: cint;
begin
  pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, nil);
  pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, nil);
  aThread := TTMThread(_para1);
  aThread.Execute;
  if (Assigned(aThread.FOnTerminated)) then
  begin
    aThread.Synchronize(@aThread.DoTerminated);
  end;
  if (aThread.FreeOnTerminate) then
  begin
    aThread.Free;
  end;
  pthread_exit(nil);
end;

{ TTMSupportApplication }

procedure TTMSupportApplication.LMSyncHandler(var TheMessage: TLMessage);
var
  SyncRecord: TTMThreadSyncRecord;
begin
  WriteLn('A Message Received');
  SyncRecord := PTMThreadSyncRecord(Pointer(TheMessage.WParam))^;
  SyncRecord.Method();
  //writeln(pthread_cond_signal(SyncRecord.SyncCond));
end;

procedure TTMThread.DoTerminated;
begin
  if (Assigned(FOnTerminated)) then
    FOnTerminated(Self);
end;

constructor TTMThread.Create;
begin
  pthread_mutex_init(@FSyncMutex, nil);
  pthread_cond_init(@FSyncCond, nil);
end;

destructor TTMThread.Destroy;
begin
  pthread_mutex_destroy(@FSyncMutex);
  pthread_cond_destroy(@FSyncCond);
  inherited Destroy;
end;

procedure TTMThread.Start;
var
  dummy: cint;
begin
  _pthread_cleanup_push();
  pthread_create(@FPThread, nil, @CallThreadExecute, Self);
end;

procedure TTMThread.Kill;
begin
  pthread_cancel(FPThread);
  //pthread_kill(FPThread,0);
end;

procedure TTMThread.Waitfor;
var
  dummy: pointer;
begin
  pthread_join(FPThread, @dummy);
end;

procedure TTMThread.Terminate;
begin
  FTerminated := True;
end;

procedure TTMThread.Synchronize(AMethod: TThreadMethod);
var
  ASyncRecord: PTMThreadSyncRecord;
begin
  New(ASyncRecord);
  ASyncRecord^.Method := AMethod;
  ASyncRecord^.SyncCond := @FSyncCond;
  ASyncRecord^.SyncMutex := @FSyncMutex;
  pthread_mutex_lock(@SyncMutex);
  SendAppMessage(LM_TMSync, PtrInt(ASyncRecord), 0);
  WriteLn('In Mutex');
  //while (pthread_cond_wait(@FSyncCond, @FSyncMutex) <> 0) do ;
  //pthread_cond_wait(@FSyncCond, @FSyncMutex);
  pthread_mutex_unlock(@SyncMutex);
  Dispose(ASyncRecord);
  WriteLn('After Mutex');
end;

//{ TSyncThread }

//procedure TSyncThread.DoSyncTaskMessage;
//begin
//  case FSyncMessage of
//    TM_ON_TASK_FINISH:
//    begin
//      FTaskManager.FOnTaskFinish(FSyncTask);
//      FTaskManager.WriteMessage(TM_FREE_TASK, FSyncTask);
//    end;
//    TM_ON_TASK_KILLED:
//    begin
//      FTaskManager.FOnTaskKilled(FSyncTask);
//      FTaskManager.WriteMessage(TM_FREE_TASK, FSyncTask);
//    end;
//    TM_ON_TASK_START:
//      FTaskManager.FOnTaskStart(FSyncTask);
//  end;
//end;

//procedure TSyncThread.Execute;
//begin
//  Synchronize(@DoSyncTaskMessage);
//end;

//constructor TSyncThread.Create(AOwner: TTaskManager);
//begin
//  inherited Create(True);
//  FreeOnTerminate := True;
//  FTaskManager := AOwner;
//end;

//procedure TSyncThread.Sync;
//begin
//  Start;
//end;

{ TTaskRunner }

procedure TTaskRunner.Execute;
begin
  FTask.Execute;
end;

constructor TTaskRunner.Create(ATask: TTask);
begin
  inherited Create;
  FreeOnTerminate := False;
  FTask := ATask;
  ATask.FWorker := Self;
end;

{ TTask }

procedure TTask.RegisterResource(AResourceClass: TResourceClass);
begin
  FResourcesClass.Add(AResourceClass);
end;

function TTask.GetResource(AResourceClass: TResourceClass): TResource;
var
  I: integer;
begin
  for I := 0 to FResources.Count - 1 do
  begin
    if (FResources.Items[I].ClassType = AResourceClass) then
    begin
      Result := FResources.Items[I];
      Exit;
    end;
  end;
  Result := nil;
end;

procedure TTask.RequestResources;
begin
end;

procedure TTask.Execute;
begin
  FState := tsRunning;
  PerformBeforeStart;
  Run;
  PerformAfterFinish;
  FState := tsTerminated;
end;

procedure TTask.PerformBeforeStart;
begin
  FOwner.WriteMessage(TM_ON_TASK_START, Self);
end;

procedure TTask.PerformAfterFinish;
begin
  FOwner.WriteMessage(TM_ON_TASK_FINISH, Self);
end;

constructor TTask.Create(AOwner: TTaskManager);
begin
  FOwner := AOwner;
  FResources := TResourceList.Create;
  FResourcesClass := TResourceClassList.Create;
end;

destructor TTask.Destroy;
var
  I: integer;
begin
  for I := 0 to FResources.Count - 1 do
  begin
    FResources[I].Free;
  end;
  FResources.Free;
  FResourcesClass.Free;
  inherited Destroy;
end;

{ TTaskManager }

procedure TTaskManager.DoSyncTaskMessage;
begin
  case FSyncMessage of
    TM_ON_TASK_FINISH:
    begin
      FOnTaskFinish(FSyncTask);
    end;
    TM_ON_TASK_KILLED:
    begin
      FOnTaskKilled(FSyncTask);
    end;
    TM_ON_TASK_START:
      FOnTaskStart(FSyncTask);
  end;
end;

function TTaskManager.GetTask(Index: integer): TTask;
begin
  Result := FTasks[Index];
end;

function TTaskManager.GetTaskCount: integer;
begin
  Result := FTasks.Count;
end;

procedure TTaskManager.ReleaseTaskResources(ATask: TTask);
var
  I: integer;
begin
  for I := 0 to ATask.FResources.Count - 1 do
  begin
    FResources.Add(ATask.FResources[I]);
  end;
  ATask.FResources.Clear;
end;

function TTaskManager.GetResource(AResourceClass: TResourceClass): TResource;
var
  I: integer;
begin
  for I := 0 to FResources.Count - 1 do
  begin
    Result := FResources[I];
    if (Result.ClassType = AResourceClass) then
    begin
      FResources.Remove(Result);
      Exit;
    end;
  end;
  Result := nil;
end;

function TTaskManager.CheckResources(ATask: TTask): boolean;
var
  AResource: TResource;
  I: integer;
begin
  Result := False;
  for I := 0 to ATask.FResourcesClass.Count - 1 do
  begin
    AResource := GetResource(ATask.FResourcesClass[I]);
    if (AResource = nil) then
    begin
      ReleaseTaskResources(ATask);
      Exit;
    end;
    ATask.FResources.Add(AResource);
  end;
  Result := True;
end;

function TTaskManager.ReadMessage: TTMMessage;
begin
  if (FPipe.AvailableSizeToRead < SizeOf(TTMMessage)) then
  begin
    Result.Message := TM_INVALID_MESSAGE;
    Result.Data := nil;
    Exit;
  end;
  FPipe.Read(Result, SizeOf(TTMMessage));
end;

procedure TTaskManager.SetWorkerCount(AValue: integer);
begin
  WriteMessage(TM_SET_WORKERS, Pointer(AValue));
end;

procedure TTaskManager.WriteMessage(AMessage: integer; TheData: Pointer);
var
  Message: TTMMessage;
begin
  Message.Message := AMessage;
  Message.Data := TheData;
  if (FPipe.Write(Message, SizeOf(TTMMessage)) <> SizeOf(TTMMessage)) then
  begin
    WriteLn(SysErrorMessage(GetLastOSError));
  end;

end;

procedure TTaskManager.DoKillTask(ATask: TTask);
begin
  if (ATask.FState = tsRunning) then
  begin
    ATask.FWorker.Kill;
    ATask.FWorker.Waitfor;
    WriteMessage(TM_ON_TASK_KILLED, ATask);
    ATask.FState := tsKilled;
    Dec(FRunningTasks);
  end
  else if (ATask.FState = tsStarting) then
  begin
    WriteMessage(TM_KILL_TASK, ATask);
  end
  else
  begin
    ATask.FState := tsKilled;
    WriteMessage(TM_ON_TASK_KILLED, ATask);
  end;
end;

procedure TTaskManager.DoSetWorkers(TheWorkerCount: integer);
begin
  FWorkerCount := TheWorkerCount;
end;

procedure TTaskManager.DoOnTaskFinish(ATask: TTask);
begin
  if (Assigned(FOnTaskFinish)) then
  begin
    //with TSyncThread.Create(Self) do
    //begin
    FSyncMessage := TM_ON_TASK_FINISH;
    FSyncTask := ATask;
    Synchronize(@DoSyncTaskMessage);
    //  Sync;
    //end;
  end;
  Dec(FRunningTasks);
end;

procedure TTaskManager.DoOnTaskKilled(ATask: TTask);
begin
  if (Assigned(FOnTaskKilled)) then
  begin
    //with TSyncThread.Create(Self) do
    //begin
    FSyncMessage := TM_ON_TASK_KILLED;
    FSyncTask := ATask;
    Synchronize(@DoSyncTaskMessage);
    //  Sync;
    //end;
  end;
end;

procedure TTaskManager.DoOnTaskPrepared(ATask: TTask);
var
  AWorker: TTaskRunner;
begin
  //if (Assigned(FOnTaskFinish)) then
  //begin
  //  FSyncMessage := TM_ON_TASK_FINISH;
  //  FSyncTask := ATask;
  //  Synchronize(@DoSyncTaskMessage);
  //end;
  ATask.FState := tsStarting;
  AWorker := TTaskRunner.Create(ATask);
  AWorker.Start;
end;

procedure TTaskManager.DoOnTaskStart(ATask: TTask);
begin
  if (Assigned(FOnTaskStart)) then
  begin
    //with TSyncThread.Create(Self) do
    //begin
    FSyncMessage := TM_ON_TASK_START;
    FSyncTask := ATask;
    Synchronize(@DoSyncTaskMessage);
    //Sync;
    //end;
  end;
end;

procedure TTaskManager.DoStart;
begin
  if (Assigned(FOnStart)) then
  begin
    FOnStart(Self);
  end;
end;

procedure TTaskManager.DoFinish;
begin
  if (Assigned(FOnFinish)) then
  begin
    FOnFinish(Self);
  end;
end;

procedure TTaskManager.Execute;
var
  AMessage: TTMMessage;
  NoTask, I: integer;
  ATask: TTask;
begin
  Synchronize(@DoStart);
  RTLeventWaitFor(FFinishEvent);
  while not Terminated do
  begin
    AMessage := ReadMessage;
    case AMessage.Message of
      TM_ADD_RESOURCE:
        FResources.Add(TResource(AMessage.Data));
      TM_ADD_TASK:
      begin
        TTask(AMessage.Data).RequestResources;
        FTasks.Add(TTask(AMessage.Data));
      end;
      TM_REMOVE_TASK:
        raise Exception.Create('This function removed. use killtask');
      TM_KILL_TASK:
        DoKillTask(TTask(AMessage.Data));
      TM_FREE_TASK:
      begin
        TTask(AMessage.Data).FWorker.Free;
        TTask(AMessage.Data).Free;
      end;
      TM_SET_WORKERS:
        DoSetWorkers(integer(AMessage.Data));
      TM_ON_TASK_FINISH:
        DoOnTaskFinish(TTask(AMessage.Data));
      TM_ON_TASK_KILLED:
        DoOnTaskKilled(TTask(AMessage.Data));
      TM_ON_TASK_START:
        DoOnTaskStart(TTask(AMessage.Data));
      TM_ON_TASK_PREPARED:
        DoOnTaskPrepared(TTask(AMessage.Data));
    end;

    if AMessage.Message = TM_INVALID_MESSAGE then
    begin
      I := 0;
      while I < FTasks.Count do
      begin
        ATask := FTasks[I];

        if (ATask.FState in [tsKilled]) then
        begin
          FTasks.Delete(I);
          Dec(I);
          ReleaseTaskResources(ATask);
          WriteMessage(TM_FREE_TASK, ATask);
        end;

        if (ATask.FState in [tsTerminated]) then
        begin
          FTasks.Delete(I);
          Dec(I);
          ReleaseTaskResources(ATask);
          WriteMessage(TM_FREE_TASK, ATask);
        end;

        Inc(I);
      end;
      EnterCriticalsection(FProcessControl);
      I := 0;
      while (FRunningTasks < FWorkerCount) and (I < FTasks.Count) do
      begin
        ATask := FTasks[I];
        if (ATask.FState in [tsReady]) then
        begin
          if (CheckResources(ATask)) then
          begin
            Inc(FRunningTasks);
            WriteMessage(TM_ON_TASK_PREPARED, ATask);
          end;
        end;
        Inc(I);
      end;
      LeaveCriticalsection(FProcessControl);
      if (FTasks.Count = 0) and (FRunningTasks = 0) then
      begin
        RTLeventResetEvent(FFinishEvent);
        Synchronize(@DoFinish);
        RTLeventWaitFor(FFinishEvent);
      end;
      //  else
      //    WriteLn(FTasks.Count, '  ', FRunningTasks);
    end;
  end;
end;

constructor TTaskManager.Create;
begin
  inherited Create;
  FPipe := TPipe.Create;
  FTasks := TTaskList.Create;
  FResources := TResourceList.Create;
  FRunningTasks := 0;
  FWorkerCount := 1;
  FFinishEvent := RTLEventCreate;
  InitCriticalSection(FProcessControl);
end;

destructor TTaskManager.Destroy;
var
  ATask: TTask;
  AResource: TResource;
begin
  Self.Terminate;
  FRunningTasks := 8888888;
  RTLeventSetEvent(FFinishEvent);
  Self.WaitFor;
  RTLeventdestroy(FFinishEvent);
  FPipe.Free;
  DoneCriticalsection(FProcessControl);
  //Todo:Free Tasks
  for ATask in FTasks do
  begin
    ATask.Free;
  end;
  //Todo:Free Resources
  for AResource in FResources do
  begin
    AResource.Free;
  end;
  inherited Destroy;
end;

procedure TTaskManager.AddTask(ATask: TTask);
begin
  WriteMessage(TM_ADD_TASK, ATask);
  RTLeventSetEvent(FFinishEvent);
end;

procedure TTaskManager.RemoveTask(ATask: TTask);
begin
  WriteMessage(TM_REMOVE_TASK, ATask);
end;

procedure TTaskManager.AddResource(AResource: TResource);
begin
  WriteMessage(TM_ADD_RESOURCE, AResource);
end;

procedure TTaskManager.KillTask(ATask: TTask);
begin
  Writeln('Kill Request');
  WriteMessage(TM_KILL_TASK, ATask);
end;

procedure TTaskManager.Pause;
begin
  EnterCriticalsection(FProcessControl);
end;

procedure TTaskManager.Resume;
begin
  LeaveCriticalsection(FProcessControl);
end;

{ TPipe }

constructor TPipe.Create;
var
  InHandle, OutHandle: THandle;
begin
  if CreatePipeHandles(InHandle, OutHandle) then
  begin
    FInputStream := TInputPipeStream.Create(InHandle);
    FOutputSteam := TOutputPipeStream.Create(OutHandle);
  end
  else
    raise EPipeCreation.Create(EPipeMsg);
end;

function TPipe.AvailableSizeToRead: longint;
begin
  Result := FInputStream.NumBytesAvailable;
end;

function TPipe.Read(var Buffer; Count: longint): longint;
begin
  Result := FInputStream.Read(Buffer, Count);
end;

function TPipe.Write(const Buffer; Count: longint): longint;
begin
  Result := FOutputSteam.Write(Buffer, Count);
end;

initialization
  pthread_mutex_init(@SyncMutex, nil);

finalization
  pthread_mutex_destroy(@SyncMutex);

end.
