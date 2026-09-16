% Shared wire examples for the MetaMo adapter and host consumer. These are
% literal fixtures, independent of the implementation's schema declarations.
contractFixtureContext(['SnapshotRef',"host-A","snapshot-1",42,7]).
contractFixtureRecord(S, R) :-
    contract_fixture_payload(S, P), contractFixtureContext(C),
    (S == 'FrameStateBundle' -> ID = "snapshot-1", Producer = "host-A"
    ; ID = "record-1", Producer = "adapter-A"),
    R = ['IntegrationRecord',[schema,S,1],['record-id',ID],
        [producer,Producer],[context,C],[payload,P]].

contract_fixture_payload('FrameStateBundle',
 ['FrameStateBundle',
  [root,['FrameStateRoot',[id,"root-1"],[revision,3],['current-frame-id',"frame-1"],
    [mode,'Slow'],['global-budget',['BudgetRef',"host-A","global-budget",2]],
    ['global-constraints',['ConstraintsRef',"host-A","global-constraints",1]]]],
  [current,['FrameStateCurrent',[id,"frame-1"],[revision,4],[parent,'None'],
    [source,"user-A"],[status,'Active'],['frame-mode','Slow'],[priority,0.5],
    ['goal-summary',"Task"],['history-summary',""],['deliverable-summary',""],
    ['results-summary',""],[budget,['BudgetRef',"host-A","frame-budget",2]],
    [constraints,['ConstraintsRef',"host-A","frame-constraints",1]],['certified-method',""]]],
  [index,['FrameStateIndex',[active,[['FrameIndexRef',[id,"frame-1"],[revision,4],[status,'Active']]]],
    [completed,[]]]],
  [relations,[['FrameStateRelation',[id,"relation-1"],[revision,0],['source-frame',"frame-1"],
    ['target-frame',"frame-2"],['relation-type','DependsOn'],[reason,"Dependency"],
    [confidence,0.7],['evidence-status','Unverified']]]],
  [runtime,['FrameStateRuntime',['new-message',false],['message-present',false],
    ['message-summary',""],['task-open',true],['task-execution-observed',[]],
    ['active-task-summary',"Task"],['last-results-summary',""],[error,""],
    ['wake-loops',0],['next-wake-at','None'],['budget-state',['BudgetRef',"host-A","frame-budget",2]]]],
  [policy,['HostPolicyRef',"host-A","policy-1",7]]]).
contract_fixture_payload('MetaMoPolicyOutput',
 ['MetaMoPolicyOutput',[mode,'Engaged'],['operation-class','execute-skill'],
  [feasibility,'Admitted'],[reason,'Feasible'],[priority,0.7],[proposal,'None']]).
contract_fixture_payload('AttentionDirective',
 ['AttentionDirective',[decision,['RecordRef',"metamo-A","decision-1"]],[target,"frame-1"],
  [slice,'CurrentFrameTask'],[task,'execute-skill'],[admission,'Admitted'],
  [reason,'Feasible'],[priority,0.7],[source,'MetaMo']]).
contract_fixture_payload('ReasonerMotivationalProposal',
 ['ReasonerMotivationalProposal',[source,nars],[kind,'propose-candidate'],
  [target,['FrameTarget',"frame-1"]],[candidate,'repair-failure'],
  [claim,['Recommend',"frame-1",'repair-failure']],[support,['Truth',1,0.8]],
  [confidence,0.8],[evidence,['EvidenceReferences',[['ObservationRef',"host-A","observation-1"]]]],
  [prediction,['Expected','Recovered']]]).
contract_fixture_payload('ExecutionOutcome',
 ['ExecutionOutcome',[decision,['RecordRef',"metamo-A","decision-1"]],
  [directive,['RecordRef',"adapter-A","directive-1"]],[proposal,'None'],
  [dispatch,['DispatchRef',"host-A","dispatch-1"]],
  [execution,['ExecutionRef',"host-A","execution-1"]],[frame,"frame-1"],
  [status,'Completed'],[reason,'ObservedSuccess'],['observed-at',1800000000000],
  ['execution-evidence',[['ObservationRef',"host-A","observation-1"]]],[verification,[]]]).
contract_fixture_payload('FrameVerificationEvidence',
 ['FrameVerificationEvidence',[relation,['RelationRef',"host-A","relation-1",0]],
  ['source-frame',"frame-1"],['target-frame',"frame-2"],['relation-type','DependsOn'],
  [reason,"Verified dependency"],['prior-confidence',0.7],['evidence-status','Confirmed'],
  ['observed-at',1800000000000],[observations,[['ObservationRef',"host-A","observation-1"]]],
  [execution,'None']]).

% Non-mutating fixture edits let both suites exercise the same wire data.
contractFixtureSet([Name|Path], Value, Record, Updated) :-
    Record = [Tag|Fields], memberchk([Name,Old],Fields),
    (Path == [] -> New = Value; contractFixtureSet(Path,Value,Old,New)),
    % Preserve exact field order, rather than rebuilding from unordered pairs.
    maplist(contract_fixture_replace(Name,New),Fields,NewFields),
    Updated = [Tag|NewFields].
contract_fixture_replace(Name,Value,Field,New) :-
    (Field = [Name,_] -> New = [Name,Value]; New = Field).
