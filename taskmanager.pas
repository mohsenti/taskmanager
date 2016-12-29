unit TaskManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, pipes, syncobjs, fgl;

const
  TM_ADD_TASK = 1;
  TM_REMOVE_TASK = TM_ADD_TASK + 1;
  TM_KILL_TASK = TM_REMOVE_TASK + 1;

  TM_ON_TASK_PREPARED = TM_KILL_TASK + 1;
  TM_ON_TASK_START = TM_ON_TASK_PREPARED + 1;
  TM_ON_TASK_FINISH = TM_ON_TASK_START + 1;
  TM_ON_TASK_KILLED = TM_ON_TASK_FINISH + 1;

  TM_CLEAR_TASKS_LIST = TM_ON_TASK_KILLED + 1;
  TM_SET_WORKERS = TM_CLEAR_TASKS_LIST + 1;

//TM_LOCK_MASSAGE_PROCESS = TM_SET_WORKERS + 1;

type

  TTMMessage = record
    Message: integer;
    Data: Pointer;
  end;
  PTMMessage = ^TTMMessage;

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

  TTask = class(TThread)
  private
    FOwner: TTaskManager;
    FResources: TResourceList;
    FResourcesClass: TResourceClassList;
  protected
    procedure RegisterResource(AResourceClass: TResourceClass);
    function GetResource(AResourceClass: TResourceClass): TResource;
    procedure RequestResources; virtual;
    procedure Run; virtual; abstract;
    procedure Execute; override;
    procedure PerformBeforeStart; virtual;
    procedure PerformAfterFinish; virtual;
  public
    constructor Create(AOwner: TTaskManager); virtual;
    destructor Destroy; override;
  end;

  TTaskList = specialize TFPGList<TTask>;

  TTaskEvent = procedure(ATask: TTask) of object;

  { TTaskManager }

  TTaskManager = class(TThread)
  private
    FOnFinish: TNotifyEvent;
    FOnStart: TNotifyEvent;
    FOnTaskError: TTaskErrorEvent;
    FOnTaskFinish: TTaskEvent;
    FOnTaskKilled: TTaskEvent;
    FOnTaskStart: TTaskEvent;

    FPipe: TPipe;
    FTasks: TTaskList;
    FResources: TResourceList;

    function GetTask(Index: integer): TTask;
    function GetTaskCount: integer;
    procedure ReleaseTaskResources(ATask: TTask);
    function GetResource(AResourceClass: TResourceClass): TResource;
    function CheckResources(ATask: TTask): boolean;
  protected
  public
    constructor Create; virtual;

    procedure AddTask(ATask: TTask);
    procedure RemoveTask(ATask: TTask);
    procedure AddResource(AResource: TResource);

    procedure KillTask(ATask: TTask);

    property Tasks[Index: integer]: TTask read GetTask; default;
    property TaskCount: integer read GetTaskCount;

    property OnStart: TNotifyEvent read FOnStart write FOnStart;
    //property OnPause: TNotifyEvent read FOnPause write FOnPause;
    //property OnResume: TNotifyEvent read FOnResume write FOnResume;
    property OnFinish: TNotifyEvent read FOnFinish write FOnFinish;

    property OnTaskFinish: TTaskEvent read FOnTaskFinish write FOnTaskFinish;
    property OnTaskStart: TTaskEvent read FOnTaskStart write FOnTaskStart;
    property OnTaskKilled: TTaskEvent read FOnTaskKilled write FOnTaskKilled;
    property OnTaskError: TTaskErrorEvent read FOnTaskError write FOnTaskError;
  end;

implementation

{ TTaskManager }

function TTaskManager.GetTask(Index: integer): TTask;
begin
  //Todo: Implement
  Result := nil;
end;

function TTaskManager.GetTaskCount: integer;
begin
  //Todo: Implement
  Result := 0;
end;

procedure TTaskManager.ReleaseTaskResources(ATask: TTask);
begin

end;

function TTaskManager.GetResource(AResourceClass: TResourceClass): TResource;
begin

end;

function TTaskManager.CheckResources(ATask: TTask): boolean;
begin

end;

{ TPipe }

constructor TPipe.Create;
begin
  CreatePipeStreams(FInputStream, FOutputSteam);
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

end.


