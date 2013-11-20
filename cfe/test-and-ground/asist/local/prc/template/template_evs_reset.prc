PROC $sc_$cpu_evs_reset
;**********************************************************************
;
;Test Name: $sc_$cpu_evs_reset
;Test Level:Build Verification
;Test Type: Functional
;
;  Original 1.0 Eva Illescas Stattel
;
;Test Description:
;     The purpose of evs_reset_tst is to verify Event Message
;     Services EVS behavior upon Power on and Processor Reset, as follows:
;
;  1st. evs_reset_tst shall verify, upon Power-On Reset:
;       correct Default ouput Ports are enabled
;       correct Event Msg Format is enabled
;       correct local event log full flag value
;       correct logging mode is enabled
;       correct default value is set for the local evt log overflow
;       counter   
;  2nd. evs_reset_tst shall, send commands to change 
;       the default values found on Power-On
;  3rd. evs_reset_tst shall verify upon Processor Reset, 
;       that the values changed at the second step are preserves
;  4th. evs_reset_tst shall, upon Power-On (again)verify that
;       all values are back to their platform defaults
;
;  Requirements Tested:  
;  Upon Power On
;       cEVS3200
;       cEVS3201
;       cEVS3202
;       cEVS3203
;  Upon Processor Reset
;       cEVS3110 (partial test)
;       cEVS3207
;       cEVS3208
;       cEVS3209
;       cEVS3210
;
;  Additional req tested (partially)
;       cEVS3017
;       cEVS3104 Because app evt msg sent ctr increments
;
;  Prerequisite conditions or constraints: 
;       System is off for at least 5 minutes 
;       before initial Power On.
;       Tester powers on system.
;       Upon Power On, Applications' Data files,
;       local event log and EVS HK information are
;       retrieved and all values therein are justified.
;       A TST EVS application exists.
;
;  Expected test results:
;
;         Upon Power On Default values shall be:
;         Correct Output Port is enabled 
;         Event Message Format is set to its default value
;         Local Event Log Full Flag is set to its default value
;         Logging Mode is set to its default value
;
;         ****** Data File shall contain Each Application's:
;                Event Message Sent Counter
;                Event message generation Enable Statuses
;                Event Type Statuses for each event type
;                Filtered Event IDs
;                Binary Filter Masks (one per registered ID)
;                Binary Filter Counters (one per registered ID)
;
write"*****************************************************************"
;  Change History
;
;         Date      Name            Description
;         ----      ----            -----------
;         03/01/05 Eva I. Stattel   Original
;         07/05/05 EIS              Updated per cFE requirements of 4/14/2005
;         07/06/05 EIS              Updated to run on CPU
;         07/26/05 EIS              Updated per Test Review and to "cleanup"
;         08/11/05 EIS              Updated after walkthrough
;         10/28/05 EIS              Updated to run with cFE Build 3.0
;         12/06/05 EIS              Updated to run with cFE Build 3.1
;                                   where status of Evt Msg Type Debug 
;                                   is DISABLE by default.
;                                   CFE_TBL has been added to cFE.
;         12/14/05 EIS              Updated the number for max num events to 8
;				    per Bld. 3.1
;         01/06/06 EIS              Build 3.1
;                                   Message Type default status has changed:
;                                     DEBUG status is DISABLE while the rest are
;				      ENABLE
;         05/11/06 EIS              Updated with correct requirement checking process
;         05/24/06 EIS              Fully updated after Bld 3.1 walkthrough
;				    reccomendations and added partial 
;				    verification of req cEVS3104
;
;	10/19/06 WFM		Created a template from the LRO version
;	04/06/07 NSS		Build 4.0.  Tests processor reset.
;    	04/11/07 NSS		Removed tests for deleted requirements CEVS3204,
;				CEVS3205, and CEVS3206.          
;
;  Procedures/Utilities Called
;         
;         Name                       Description
;         ----                       ------------
;         ut_runproc                 To run the proc and do initial set up stuff
;         ut_pfindicate              To write out status of either pass or fail 
;                                    for requirements tested
;         load_start_app             To load and initialize Test Application
;         get_file_to_cvt            To retrieve Applications' Data
;         $sc_$cpu_evs_dflt_chk      Checks EVS default values.
;
;**********************************************************************
;         Include Files
;**********************************************************************

#include "ut_statusdefs.h"       
#include "cfe_platform_cfg.h"
#include "cfe_evs_reset_reqts.h"
#include "cfe_mission_cfg.h" 
#include "cfe_evs_events.h"
#include "cfe_es_events.h"
#include "cfe_sb_events.h"
#include "cfe_time_events.h"
#include "cfe_tbl_events.h"
#include "tst_evs_events.h"

;**********************************************************************
;  Define variables
;**********************************************************************
;
local test_app_lctn = 0
local saveLclEvtLogOverFlowCtr = 0
local saveLclEvtLogFullFlag = 0
local saveLoggingMode = 0
local saveEventMsgFormat = 0
local saveProcessResetCnt = 0
local totalevtmsgsentctr = 0
local apps = 0
local i = 0

FOR i = 0 to ut_req_array_size DO
   ut_requirement[i] = "U"
ENDDO 

local cfe_requirements[0..ut_req_array_size] = ["cEVS3017", "cEVS3104","cEVS3110", "cEVS3200", "cEVS3201", "cEVS3202", "cEVS3203", "cEVS3207", "cEVS3208", "cEVS3209", "cEVS3210"]
;

local added_app_id = 0
local apps_regstrd_before_tst_app = 0
local all_apps_registered = 0
local cfe_plus_tst_apps = 8
local all_apps[1..cfe_plus_tst_apps] = ["CFE_EVS","CFE_SB","CFE_ES","CFE_TIME","CFE_TBL","CI_LAB_APP","TO_LAB_APP","TST_EVS"]
;
; variables used to save initial values for app names, evt msg gen enable status
; evt msg types and app evt msg counters and bin flt ctrs
;
local SAVE_EVS_AppData_AppName[CFE_ES_MAX_APPLICATIONS]
;
local AppCtr = "EventCounter"
local added_App_EvtMsgSntCtr = 0
;
local hostname = %liv(LOCALHOST) ; get hostname from ASIST STOL local internal variable

; strip off 'gpm-' from rainman hostname
if (%locate(hostname,"-") <> 0) then
  hostname = %substring(hostname,%locate(hostname,"-")+1,%length(hostname))
  hostname = %upper(hostname)
endif
;
write"*****************************************************************"
write " Step 1.0: EVS Reset Test"
write"*****************************************************************"
write " Step 1.1: Command a Power-On Reset on $CPU"
write"*****************************************************************"
/$SC_$CPU_ES_POWERONRESET
wait 10
                                                                                
close_data_center
wait 75
                                                                                
cfe_startup $CPU
wait 5

write ";*********************************************************************"
write "; Enable DEBUG Event Messages "
write ";*********************************************************************"
ut_setupevt "$SC", "$CPU", "CFE_EVS", CFE_EVS_ENAEVTTYPE_EID, "DEBUG"
                                                                                
ut_sendcmd "$SC_$CPU_EVS_ENAEVENTTYPE DEBUG"
if (UT_SC_Status = UT_SC_Success) then
  write "<*> Passed - Debug events have been enabled."
  if ($SC_$CPU_num_found_messages = 1) then
    Write "<*> Passed - Event Msg ",$SC_$CPU_find_event[1].eventid," Found!"
  else
    Write "<!> Failed - Event Message not received for ENAEVENTTYPE command."
  endif
else
  write "<!> Failed - Could not enable Debug events."
endif

write"*****************************************************************"
write " Step 1.2: Retrieve the application data file "
write "           Retrieve the number of applications registered."
write"*****************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "$sc_$cpu_evs12.tst_appdat", "$CPU")
wait 5

local cfe_evs_ndx=0, cfe_sb_ndx=0, cfe_es_ndx=0, cfe_time_ndx=0, cfe_tbl_ndx=0

FOR apps = 1 to CFE_ES_MAX_APPLICATIONS DO
  if ($sc_$cpu_EVS_AppData[apps].AppName <> "") then  
    apps_regstrd_before_tst_app = apps_regstrd_before_tst_app + 1
    write "Application Name = ", $sc_$cpu_evs_AppData[apps].AppName, " APP ID = ", $sc_$cpu_EVS_APP[apps].APPID
  endif

  ;; Set the local index variables for the cFE Core tasks
  if ($sc_$cpu_EVS_AppData[apps].AppName =  "CFE_EVS") then  
    cfe_evs_ndx = apps
  elseif ($sc_$cpu_EVS_AppData[apps].AppName =  "CFE_SB") then  
    cfe_sb_ndx = apps
  elseif ($sc_$cpu_EVS_AppData[apps].AppName =  "CFE_ES") then  
    cfe_es_ndx = apps
  elseif ($sc_$cpu_EVS_AppData[apps].AppName =  "CFE_TIME") then  
    cfe_time_ndx = apps
  elseif ($sc_$cpu_EVS_AppData[apps].AppName =  "CFE_TBL") then  
    cfe_tbl_ndx = apps
  endif
ENDDO           

;counter for CFE_ES task
LOCAL App3EvtMsgSntCtr = $sc_$cpu_EVS_APP[cfe_es_ndx].APPMSGSENTC

write "+++++++++++++++++++++++++++++++++++++++++"
write " Upon Power On, number of registered apps = ", apps_regstrd_before_tst_app            
;
write"*****************************************************************"
write " Step 1.3 Load & start the EVS Test Application"
write"*****************************************************************"
;
ut_setupevt "$SC", "$CPU", TST_EVS, TST_EVS_INIT_INF_EID, INFO

start load_start_app ("TST_EVS", "$CPU")
wait 25
;
if ($sc_$cpu_num_found_messages = 1) then
  added_App_EvtMsgSntCtr = added_App_EvtMsgSntCtr + 1
  all_apps_registered = apps_regstrd_before_tst_app + 1
  added_app_id = $sc_$cpu_evs_app[all_apps_registered].appid
  App3EvtMsgSntCtr = App3EvtMsgSntCtr + 1
else
  write "ALERT: failure to find test app init evt msg"
  goto end_it
endif

;
write"*****************************************************************"
write " Step 1.4: Retrieve the application data file "
write "           Retrieve the number of applications registered."
write"*****************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "$sc_$cpu_evs14.tst_appdat", "$CPU")
wait 5

write "& & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & "
write " Current number of registered applications = ", all_apps_registered
FOR apps = 1 to CFE_ES_MAX_APPLICATIONS DO
  WRITE " Iteration = ", apps                      
  write "Application Name = ", $sc_$cpu_evs_AppData[apps].AppName, " APP ID = ", $sc_$cpu_EVS_APP[apps].APPID

  if ($sc_$cpu_EVS_AppData[apps].AppName = "TST_EVS") then  
    test_app_lctn = apps
    write "apps = ", apps
  endif
ENDDO
write "& & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & "

write "Added test app location = ", test_app_lctn

if ($sc_$cpu_EVS_APP[test_app_lctn].APPMSGSENTC =  added_App_EvtMsgSntCtr) then
  ut_setrequirements cEVS3104, "P"
  write "Added Application ID = ", $sc_$cpu_evs_app[test_app_lctn].appid
  if ($sc_$cpu_EVS_APP[cfe_es_ndx].APPMSGSENTC = App3EvtMsgSntCtr) then
    ut_setrequirements cEVS3104, "P"
  else 
    ut_setrequirements cEVS3104, "F"
    write "ALERT: CFE_ES evt msg sent ctr failed to increment at Start/Load app"
  endif
else
  ut_setrequirements cEVS3104, "F"
  write "ALERT: evt msg sent ctr failed to increment at initialize app!!!!"
endif   

write "TST_EVS evt msg sent counter = ", $sc_$cpu_EVS_APP[test_app_lctn].APPMSGSENTC
write "CFE_ES evt msg sent ctr = ", $sc_$cpu_EVS_APP[cfe_es_ndx].APPMSGSENTC
;
write"*************************************************************************"
write " Step 1.5: Verify default values via sub-proc which checks EVS default" 
write "           values."
write"*************************************************************************"
;
start $sc_$cpu_evs_dflt_chk

ut_tlmwait $SC_$CPU_EVS_LOGMODE, 0 
write"*************************************************************************"
write "           CHANGE-><-CHANGE-><-CHANGE-><-CHANGE-><-CHANGE-><-CHANGE"
write " Step 2.0: Change Default Values for output ports, evt msg format, log"
write "		  full flag and logging mode."
write "           CHANGE-><-CHANGE-><-CHANGE-><-CHANGE-><-CHANGE-><-CHANGE"
write"*************************************************************************"
write " Step 2.1: Send Cmds to cause each app's evt counter to increment"
write"*************************************************************************"
ut_setupevt "$SC", "$CPU", CFE_EVS, CFE_EVS_NOOP_EID, INFO

/$SC_$CPU_EVS_NOOP
wait 3

if ($sc_$cpu_find_event[1].event_txt = "" ) then
  write " ALERT: EVS no-op evt msg NOT found"
endif

ut_setupevt "$SC", "$CPU", CFE_SB, CFE_SB_CMD0_RCVD_EID, INFO

/$SC_$CPU_SB_NOOP
wait 3

if ($sc_$cpu_find_event[1].event_txt = "" ) then
  write " ALERT: SB no-op evt msg NOT found"
endif

ut_setupevt "$SC", "$CPU", CFE_ES, CFE_ES_NOOP_INF_EID, INFO

/$SC_$CPU_ES_NOOP
wait 3

if ($sc_$cpu_find_event[1].event_txt = "" ) then
  write " ALERT: ES no-op evt msg NOT found"
endif

ut_setupevt "$SC", "$CPU", CFE_TIME, CFE_TIME_NOOP_EID, INFO

/$SC_$CPU_TIME_NOOP
wait 3

if ($sc_$cpu_find_event[1].event_txt = "" ) then
  write " ALERT: TIME no-op evt msg NOT found"
endif

ut_setupevt "$SC", "$CPU", CFE_TBL, CFE_TBL_NOOP_INF_EID, INFO

/$SC_$CPU_TBL_NOOP
wait 3

if ($sc_$cpu_find_event[1].event_txt = "" ) then
  write " ALERT: TBL no-op evt msg NOT found"
endif

ut_setupevt "$SC", "$CPU", CI_LAB_APP, 5, INFO

/$SC_$CPU_CI_NOOP
wait 3

if ($sc_$cpu_find_event[1].event_txt = "" ) then
  write " ALERT: CI no-op evt msg NOT found"
endif

ut_setupevt "$SC", "$CPU", TO_LAB_APP, TO_NOOP_INF_EID, INFO

/$SC_$CPU_TO_NOOP
wait 3

if ($sc_$cpu_find_event[1].event_txt = "" ) then
  write " ALERT: TO no-op evt msg NOT found"
endif

ut_setupevt "$SC", "$CPU", TST_EVS, TST_EVS_NOOP_INF_EID, INFO

/$SC_$CPU_TST_EVS_NOOP
wait 5

if ($sc_$cpu_find_event[1].event_txt = "" ) then
  write " ALERT: TST EVS no-op evt msg NOT found"
endif
     
write"*************************************************************************"
write " Step 2.1.1: Retrieve the application data file and the local event log"
write "            examine and account for all values therein"
write"*************************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "$sc_$cpu_rst_211.tst_appdat", "$CPU")

start get_file_to_cvt ("RAM:0", "cfe_evs.log", "$sc_$cpu_rst_211.log", "$CPU")
wait 5

write "************************************************************************"
write " Step 2.2: To cause app binary filter ctr increment:"
write "              Request generation of 10 iters of evt msg 1 with type INFO"
write "              Evt msg 1 is registered for filtering"
write "              with a mask of value = 0, which means always send"
write "************************************************************************"
;
added_App_EvtMsgSntCtr = added_App_EvtMsgSntCtr + 1

/$SC_$CPU_TST_EVS_SendEvtMsg INFO EventId="1" Iters = "10" MILLISECONDS = "150"
wait 5
; 
write "************************************************************************"
write " Step 2.2.1: Retrieve app data"
write "             To verify app binary filter ctr increment"
write "************************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "$sc_$cpu_rst_221.tst_appdat", "$CPU")
wait 5

if ($sc_$cpu_EVS_AppData[test_app_lctn].BinFltr[1].Ctr <> 10) then
  write" ALERT: TST_EVS binary filter counter for evt msg 1 failed to increment"
endif

write " Test app bin fltr ctr for evt msg ID 1 = ", $sc_$cpu_EVS_AppData[test_app_lctn].BinFltr[1].Ctr
;
write "************************************************************************"
write " Step 2.2.2: Retrieve local evt log"
write "************************************************************************"

start get_file_to_cvt ("RAM:0", "cfe_evs.log", "$sc_$cpu_rst_222.log", "$CPU")
wait 5

write"*************************************************************************"
write " Step 2.3: Change Port Default Configuration"
write"*************************************************************************"
write " Step 2.3.1: Disable Port 1"
write"*****************************************************************"

/$SC_$CPU_EVS_DISPORT PORT_ONE              
wait 5 

if  (%bin($SC_$CPU_EVS_OUTPUTPORT) = 0000) then
  ut_setrequirements cEVS3200, "P"
  write "Output Ports Bitmask value = ", %bin($SC_$CPU_EVS_OUTPUTPORT)  
else
  ut_setrequirements cEVS3200, "F"
  write "ALERT: failure to change default port configuration"
endif

write"*************************************************************************"
write " Step 2.3.2: To verify that all ports are set to DISABLE."
write "             Request generation of event message 1 of INFO type via "
write "		    Test Application."
write "             Since Event Output Port 1 is disabled, no evt msgs shall "
write "             occur there TST_EVS evt msg ctr shall increment"
write "             Events are visible in the Local Evt Log and the ASIST log"
write"*************************************************************************"

ut_setupevt "$SC", "$CPU", TST_EVS, TST_EVS_TST1_INF_EID, INFO

/$SC_$CPU_TST_EVS_SendEvtMsg INFO EventId="1" Iters = "5" MILLISECONDS = "150"
wait 15

if ($sc_$cpu_num_found_messages = 5) then
  ut_setrequirements cEVS3104, "P"
  write " TST_EVS evt msg sent ctr = ", $sc_$cpu_EVS_APP[test_app_lctn].APPMSGSENTC   
else
  ut_setrequirements cEVS3104, "F"
  write "*** ALERT: TST_EVS  msg sent counter not incremented"
endif

write"*************************************************************************"
write " Step 2.3.3: Enable Port 2"     
write"*************************************************************************"
;
/$SC_$CPU_EVS_ENAPORT PORT_TWO
wait 5 

if  ($SC_$CPU_EVS_OUTPUTPORT = 2) then 
  ut_setrequirements cEVS3017, "P"
  write "** Output Ports Bitmask value = ", %bin($SC_$CPU_EVS_OUTPUTPORT)  
else 
  ut_setrequirements cEVS3017, "F"
  write "*** ALERT: failure to enable Port 2"
endif
;
write"*************************************************************************"
write " Step 2.3.4: To verifty that Event Output port 2 is ENABLE"
write "             Request generation of 3 iters of event message 1 of" 
write "             error type via Test Application"
write "             Event messages shall occur only at output port 2 "
write"*************************************************************************"

ut_setupevt $SC, $CPU, TST_EVS, TST_EVS_TST1_INF_EID, ERROR

/$SC_$CPU_TST_EVS_SendEvtMsg ERROR EventId="1" Iters = "3" MILLISECONDS = "150"
wait 15

if ($SC_$CPU_num_found_messages <> 3) then
  ut_setrequirements cEVS3200, "F"
  write " ALERT: cEVS3200 failed; wrong number of evt msgs found = ", $SC_$CPU_num_found_messages
else
  ut_setrequirements cEVS3200, "P"
endif
;
write"*************************************************************************"
write " Step 2.3.5: Enable Port 4"     
write"*************************************************************************"
;
/$SC_$CPU_EVS_ENAPORT PORT_FOUR
wait 5

if  ($SC_$CPU_EVS_OUTPUTPORT = 10) then
  ut_setrequirements cEVS3017, "P"
  write "**** Output Ports Bitmask value = ", %bin($SC_$CPU_EVS_OUTPUTPORT)
else 
  ut_setrequirements cEVS3017, "F"
  write "*** ALERT: failure to enable Port 4"
endif
;
write"*************************************************************************"
write " Step 2.3.6: To verify evt output port 4 ENABLE"
write "             Request generation of event message 1 of type INFO"
write "             Event messages shall occur at output ports 2 and 4."
write"*************************************************************************"
;
ut_setupevt $SC, $CPU, TST_EVS, TST_EVS_TST1_INF_EID, INFO

/$SC_$CPU_TST_EVS_SendEvtMsg INFO EventId="1" Iters = "4" MILLISECONDS = "150"
wait 15

if ($sc_$cpu_num_found_messages <> 4) then
  ut_setrequirements cEVS3017, "F"
  write " ALERT: cEVS3200 failed; wrong number of evt msgs found = ", $sc_$cpu_num_found_messages
else
  ut_setrequirements cEVS3017, "P"
endif
;
write"*************************************************************************"
write " Step 2.3.7: To verify default (LONG) enabled Evt Msg Format"
write "             Trigger Event Messages of type INFO and note that" 
write "             they are generated."
;                   cEVS3201
write"*************************************************************************"
;
ut_setupevt $SC, $CPU, TST_EVS, TST_EVS_LONGLONGLONGMSG_INF_EID, INFO

/$SC_$CPU_TST_EVS_SendEvtMsg INFO EventId="6" Iters = "4" MILLISECONDS = "150"
wait 15

if ($sc_$cpu_num_found_messages <> 4) then
  write " ALERT: wrong number of evt msgs found = ", $sc_$cpu_num_found_messages
else
  if ($sc_$cpu_find_event[1].event_txt <> "") then
    ut_setrequirements cEVS3201, "P"
  else
    ut_setrequirements cEVS3201, "F"
    write "*** ALERT: cEVS3201 failed at check of LONG evt msg format"
  endif
endif
                    
;
start get_file_to_cvt ("RAM:0", "cfe_evs.log", "rst_237.log", "$CPU")
wait 5

write"*************************************************************************"
write " Step 2.4: Change the Event Message Format to Short"
write"*************************************************************************"
;
/$SC_$CPU_EVS_SETEVTFMT SHORT 
wait 5
;
if  (p@$SC_$CPU_EVS_MSGFMTMODE = "SHORT") then
  ut_setrequirements cEVS3201, "P"
  write " event message format set to ", p@$SC_$CPU_EVS_MSGFMTMODE
else
  ut_setrequirements cEVS3201, "F"
  write "*** ALERT: failure to set SHORT event format "
endif

write"*************************************************************************"
write " Step 2.4.1: To verify SHORT evt msg format enabled"
write "             Trigger Event Messages of type ERROR and verify that "
write"              they are generated in the short format"
write"*************************************************************************"
;
ut_setupevt $SC, $CPU, TST_EVS, TST_EVS_TST1_INF_EID, ERROR

/$SC_$CPU_TST_EVS_SendEvtMsg ERROR EventId="1" Iters="4" MILLISECONDS = "150"
wait 15

if ($sc_$cpu_num_found_messages <> 4) then
  write " ALERT: wrong number of evt msgs found = ", $sc_$cpu_num_found_messages
else 
  if ($sc_$cpu_find_event[1].event_txt = "") then
    ut_setrequirements cEVS3201, "P"
    write " event message format set to ", p@$sc_$cpu_EVS_MSGFMTMODE  
  else
    ut_setrequirements cEVS3201, "F"
    write "*** ALERT: failure at check of SHORT evt msg format"
  endif
endif

;
write"*************************************************************************"
write " Step 2.4.2: Retrieve the application data file and local event log " 
write "             and examine them and account for their contents"
write"*************************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "rst_242.tst_appdat", "$CPU" )
wait 5

start get_file_to_cvt ("RAM:0", "cfe_evs.log", "rst_242.log", "$CPU")
wait 5
;
write"*************************************************************************"
write " Step 2.5: Change the Logging Mode to DISCARD"
write"*************************************************************************"
;
/$SC_$CPU_EVS_SETLOGMODE DISCARD 
ut_tlmwait $SC_$CPU_EVS_LOGMODE, 1

if ($SC_$CPU_EVS_LOGMODE <> 1) THEN
  write "*** ALERT: Failed to set logging mode to DISCARD" 
endif

write "Logging mode = ",p@$SC_$CPU_EVS_LOGMODE

write"*************************************************************************"
write " Step 2.5.1: To verify change of Logging Mode, request generation of 10"
write "		    evt msgs via test app then retrieve Local Event Log and "
write "		    verify these msgs do not exist."
write"*****************************************************************"
;
/$SC_$CPU_TST_EVS_SendEvtMsg CRIT EventId="1" Iters="10" MILLISECONDS = "150"
wait 15

start get_file_to_cvt ("RAM:0", "cfe_evs.log", "rst_251.log", "$CPU")
wait 5

write"*************************************************************************"
write " Step 2.6: Change statuses of event data types from their "
write "           respective defaults."
write "           Debug     DIS -> ENA"
write "           Info      ENA -> DIS"
write "           Error     ENA -> DIS"
write "           Critical  ENA -> DIS"
write"************************************************************************"
;
/$SC_$CPU_EVS_ENAEVENTTYPE DEBUG 
wait 8

/$SC_$CPU_EVS_DISEVENTTYPE INFO 
wait 8

/$SC_$CPU_EVS_DISEVENTTYPE ERROR 
wait 8

/$SC_$CPU_EVS_DISEVENTTYPE CRIT 
wait 8

write"*************************************************************************"
write " Step 2.6.1: Retrieve the application data file, and Local Event Log" 
write "             examine them and account for contents"
write "             NOTE: Expect 2 DEBUG evt msgs upon data file retrieval"
write"*************************************************************************"
;
totalevtmsgsentctr =  $SC_$CPU_EVS_MSGSENTC
totalevtmsgsentctr =  totalevtmsgsentctr + 2

start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "261.tst_appdat", "$CPU")

ut_tlmwait $SC_$CPU_EVS_MSGSENTC, {totalevtmsgsentctr}
 
if (ut_tw_status <> UT_TW_Success) then
  write " ALERT: unexpected total evt msg sent ctr value = ", $SC_$CPU_EVS_MSGSENTC
endif

write"*************************************************************************"
write " Step 2.7: Disable for tasks and test application the future "
write "		  generation of all event Messages"
write "*****************************************************************"
;  
for i = 1 to cfe_plus_tst_apps do
  /$SC_$CPU_EVS_DISAPPEVGEN APPLICATION=all_apps[i]
  ut_tlmwait $sc_$cpu_EVS_APP[i].APPENASTAT, 0
ENDDO                
;                 
write " ***********************************************************************"
write " Step 2.7.1: Retrieve the application data file and local event log " 
write "             and examine them and account for their contents"
write " ***********************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "271.tst_appdat", "$CPU")
wait 5

write "    *****************************************************************"
write "    Status of Event Message Generation for cFE and test app registered applications"
;
for apps = 1 to CFE_ES_MAX_APPLICATIONS do 
   if  ($sc_$cpu_EVS_AppData[apps].AppName <> "") then
     if  ($sc_$cpu_EVS_APP[apps].APPENASTAT = 0) then
        write " ***** Event Message Generation Status for Application ", $SC_$CPU_EVS_AppData[apps].AppName, " is ", p@$sc_$cpu_EVS_APP[apps].APPENASTAT
     endif
   endif
enddo
;
write "************************************************************************"
write " Step 2.7.2: To verify DISABLE status of evt msg generation"
write "             Send cmds to trigger an event "
write "             message from each application"
write "             and observe that they are NOT generated"
write "************************************************************************"
; 
ut_setupevt $SC, $CPU, CFE_EVS, 0, INFO

/$SC_$CPU_EVS_NOOP
wait 3

if ($sc_$cpu_num_found_messages > 0) then
  write " ALERT: unexpected EVS no-op evt msg found"
endif

ut_setupevt $SC, $CPU, CFE_SB, 35, INFO

/$SC_$CPU_SB_NOOP
wait 3

if ($sc_$cpu_num_found_messages > 0) then
  write " ALERT: unexpected SB no-op evt msg found"
endif

ut_setupevt $SC, $CPU, CFE_ES, 3, INFO

/$SC_$CPU_ES_NOOP
wait 3

if ($sc_$cpu_num_found_messages > 0) then
  write " ALERT: unexpected ES no-op evt msg found"
endif

ut_setupevt $SC, $CPU, CFE_TIME, 4, INFO

/$SC_$CPU_TIME_NOOP
wait 3

if ($sc_$cpu_num_found_messages > 0) then
  write " ALERT: unexpected TIME no-op evt msg found"
endif

ut_setupevt $SC, $CPU, CFE_TBL, 10, INFO

/$SC_$CPU_TBL_NOOP
wait 3

if ($sc_$cpu_num_found_messages > 0) then
  write " ALERT: unexpected TBL no-op evt msg found"
endif

ut_setupevt $SC, $CPU, CI_LAB_APP, 5, INFO

/$SC_$CPU_CI_NOOP
wait 3

if ($sc_$cpu_num_found_messages > 0) then
  write " ALERT: unexpected CI no-op evt msg found"
endif

ut_setupevt $SC, $CPU, TO_LAB_APP, 18, INFO

/$SC_$CPU_TO_NOOP
wait 3

if ($sc_$cpu_num_found_messages > 0) then
  write " ALERT: unexpected TO no-op evt msg found"
endif

ut_setupevt $SC, $CPU, TST_EVS, 17, INFO

/$SC_$CPU_TST_EVS_NOOP
wait 5

if ($sc_$cpu_num_found_messages > 0) then
  write " ALERT: unexpected TST EVS no-op evt msg found"
endif

write "************************************************************************"
write " Step 2.7.2.1: To verify the DISABLE status of evt message generation"
write "               retrieve the Local Event Log and verify the absence of"
write "		      no-op evt msgs"
write "************************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs.log", "rst_252.log", "$CPU")
wait 5

write "************************************************************************"
write "           *****  Before Causing Processor Reset Save info ***** "
write "************************************************************************"
write " Step 2.8: Check output ports value"
write "************************************************************************"
;
if ($sc_$cpu_EVS_OUTPUTPORT = 1) then 
  write "ALERT! ALERT! wrong Output Port mask ", $SC_$CPU_EVS_OUTPUTPORT
else
  write " Output Port Mask = ", $SC_$CPU_EVS_OUTPUTPORT
endif 

write "************************************************************************"
write" Step 2.8.1: Save the event message format"
write "************************************************************************"
;
saveEventMsgFormat = p@$SC_$CPU_EVS_MSGFMTMODE
if (p@$SC_$CPU_EVS_MSGFMTMODE <> "SHORT") then
  write " ALERT! ALERT! wrong event msg format ", $SC_$CPU_EVS_MSGFMTMODE
else
  write " Event Message Format = ", $SC_$CPU_EVS_MSGFMTMODE
endif
                 
; 
write "************************************************************************"
write" Step 2.8.2: Save the local event log full flag"
write "************************************************************************"
;
if (p@$SC_$CPU_EVS_LOGFULL = "TRUE") AND ($SC_$CPU_EVS_LOGOVERFLOWC >= 1) then
  saveLclEvtLogFullFlag =  p@$SC_$CPU_EVS_LOGFULL 
  write " Value of local event log full flag value is ", p@$SC_$CPU_EVS_LOGFULL
else
  write "ALERT: the local event log full flag must be set to true prior to"
  write "processor reset; it is =  ", p@$SC_$CPU_EVS_LOGFULL
endif

;
write "************************************************************************"
write" Step 2.8.2.1: Save the local event log overflow counter"
write "************************************************************************"
;
if ($SC_$CPU_EVS_LOGOVERFLOWC > 0) then
  saveLclEvtLogOverFlowCtr = $SC_$CPU_EVS_LOGOVERFLOWC
  write " Local event log overflow counter = ", $SC_$CPU_EVS_LOGOVERFLOWC
else
  write " ALERT! ALERT! the local event log overlow counter value must "
  write " be greater than zero before reset"
endif
;
;
write "************************************************************************"
write" Step 2.8.3: Save the logging mode"
write "************************************************************************"
;
saveLoggingMode = $SC_$CPU_EVS_LOGMODE
if (p@$SC_$CPU_EVS_LOGMODE <> "DISCARD") then
  write "ALERT! ALERT! wrong logging mode = ", p@$SC_$CPU_EVS_LOGMODE," (",$SC_$CPU_EVS_LOGMODE,")"
else
  write " Logging Mode = ", p@$SC_$CPU_EVS_LOGMODE
endif 
;
write "************************************************************************"
write" Step 2.8.4: Retrieve the application data file and local event log " 
write "            and examine them and account for their contents"
write "************************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "264.tst_appdat", "$CPU")
wait 5

start get_file_to_cvt ("RAM:0", "cfe_evs.log", "rst_284.log", "$CPU")
wait 5

;
; Prior to Processor Reset
; Save registered apps info:
; Name, evt msg gen status, evt msg types statuses, evt msg sent ctrs and bin fltr ctrs
; Listing registered apps
;
WRITE "Saving Names for registered apps."

FOR i = 1 to CFE_ES_MAX_APPLICATIONS DO
  if ($SC_$CPU_EVS_AppData[i].AppName <> "") then
    write "Registered Application Name = ", $SC_$CPU_EVS_AppData[i].AppName,  " APP ID = ", $sc_$cpu_EVS_APP[i].APPID
    SAVE_EVS_AppData_AppName[i] = $SC_$CPU_EVS_AppData[i].AppName
  endif
ENDDO
;
write "************************************************************************"
write " Step 3.0: Command a Processor Reset"
write "************************************************************************"

write "BEFORE RESET: Processor Reset Count = ", $SC_$CPU_ES_PROCRESETCNT
saveProcessResetCnt = $SC_$CPU_ES_PROCRESETCNT

/$SC_$CPU_ES_PROCESSORRESET
wait 10

close_data_center
wait 75

cfe_startup $CPU
wait 5

write "AFTER RESET: Processor Reset Count = ", $SC_$CPU_ES_PROCRESETCNT
if ($SC_$CPU_ES_PROCRESETCNT = saveProcessResetCnt + 1) then
   write "Processor Reset Count incremented as expected."
else
   write "**** ALERT ***** Processor Reset Count did *not* increment as expected."
endif

;
write "*****************************************************************"
write " Step 3.1: Retrieve data file and local event log"
write " 	  Verify preservation of contents of the Local Event Log"
write "           by comparing to the one created prior to Processor Reset"
write "*****************************************************************"
;
start get_file_to_cvt ("RAM:0", "cfe_evs_app.dat", "301.tst_appdat", "$CPU")
wait 5

start get_file_to_cvt ("RAM:0", "cfe_evs.log", "rst_301.log", "$CPU")
wait 5
ut_setrequirements cEVS3207, "A" 
;
write"*************************************************************************"
write " Step 3.2: Verify that Local Event Log Full Flag value (TRUE) was "
write "		  preserved "
write"*************************************************************************"
;
if (p@$SC_$CPU_EVS_LOGFULL = saveLclEvtLogFullFlag) then
  ut_setrequirements cEVS3208, "P" 
  write "Value of Local Event Log Full Flag is ", p@$SC_$CPU_EVS_LOGFULL
else
  ut_setrequirements cEVS3208, "F" 
  write "**** ALERT: incorrect value for Local Event Log Full Flag = ", p@$SC_$CPU_EVS_LOGFULL
  write "**** Expected: ", saveLclEvtLogFullFlag
endif
;
write"*************************************************************************"
write " Step 3.3: Verify that the Logging Mode was preserved "
write"*************************************************************************"
;
if ($SC_$CPU_EVS_LOGMODE = saveLoggingMode) then
  ut_setrequirements cEVS3209, "P" 
  write "Passed (3209) - Value of Local Event Log Mode is ", p@$SC_$CPU_EVS_LOGMODE
else
  ut_setrequirements cEVS3209, "F" 
  write "Failed (3209) - Incorrect Logging Mode = ", p@$SC_$CPU_EVS_LOGMODE, "(", $SC_$CPU_EVS_LOGMODE,")"
  write "**** Expected: ", saveLoggingMode
endif
;
write"*************************************************************************"
write " Step 3.4: Verify Local Event Log Overflow Counter value was preserved"
write"*************************************************************************"
;
if ($SC_$CPU_EVS_LOGOVERFLOWC >= saveLclEvtLogOverFlowCtr) then
  ut_setrequirements cEVS3210, "P" 
  write "Value of Local Event Log Overflow Ctr is ", $SC_$CPU_EVS_LOGOVERFLOWC
  write "**** Expected: >= ", saveLclEvtLogOverFlowCtr
else
  ut_setrequirements cEVS3210, "F" 
  write "**** ALERT: incorrect Evt Ovrflow Ctr = ", $SC_$CPU_EVS_LOGOVERFLOWC   
  write "**** Expected: ", saveLclEvtLogOverFlowCtr
endif
;
write"*************************************************************************"
write " Step 3.5: Following processor reset, EVS should have freed the "
write " 	  resources for application TST_EVS. Application data is "
write "		  checked here to confirm TST_EVS is no longer running."
write"*************************************************************************"
;

FOR i = 1 to CFE_ES_MAX_APPLICATIONS DO
  if ($SC_$CPU_EVS_AppData[i].AppName <> "") then
    write "Registered Application Name = ", $SC_$CPU_EVS_AppData[i].AppName,  " APP ID = ", $sc_$cpu_EVS_APP[i].APPID

    IF ($SC_$CPU_EVS_AppData[i].AppName = "TST_EVS")  THEN
      ut_setrequirements cEVS3110, "F"
    ELSE
      ut_setrequirements cEVS3110, "P"
    ENDIF
  endif
ENDDO 
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;
write"*************************************************************************"
write "Step 4.0: Command PowerOn Reset"
write"*************************************************************************"
;
write "Sending PowerOnReset for $CPU"                      
/$SC_$CPU_ES_POWERONRESET
wait 10

close_data_center
wait 75

cfe_startup $cpu
wait 5

;
write"*************************************************************************"
write "Step 4.1: Upon Power On; using sub-proc:"
write "              Verify default values for port enabled, evt msg format"
write "              log full flag and logging mode"
write"*****************************************************************"
;
;start $sc_$cpu_evs_dflt_chk
;; The steps below are copied from the evs_dflt_chk proc because they did not
;; seem to work in the sub-proc
if ($sc_$cpu_EVS_OUTPUTPORT = 1) then
  ut_setrequirements cEVS3200, "P"
else
  ut_setrequirements cEVS3200, "F"
  write " ALERT: cEVS3200 failed when checking default value for evt port enabled"
endif
write " Output Ports Enabled ", %bin($sc_$cpu_EVS_OUTPUTPORT, 4)
;
if (p@$sc_$cpu_EVS_LOGFULL = "FALSE") then
  ut_setrequirements cEVS3202, "P"
else
  ut_setrequirements cEVS3202, "F"
  write " ALERT: cEVS3202 failed when checking default value for Log Full flag"
endif
write " Local event log full flag = ", p@$sc_$cpu_EVS_LOGFULL

if (p@$sc_$cpu_EVS_MSGFMTMODE = "LONG") then
  ut_setrequirements cEVS3201, "P"
else
  ut_setrequirements cEVS3201, "F"
  write " ALERT: cEVS3201 failed when checking default value for evt msg format"
endif
write " Event Msg Format = ", p@$sc_$cpu_EVS_MSGFMTMODE
;
if ($sc_$cpu_EVS_LOGMODE = CFE_EVS_DEFAULT_LOG_MODE) then
  ut_setrequirements cEVS3203, "P"
else
  ut_setrequirements cEVS3203, "P"
  write " ALERT: cEVS3203 failed when checking default value for logging mode"
endif
write " Logging Mode = ", p@$sc_$cpu_EVS_LOGMODE

;
ut_tlmwait $SC_$CPU_EVS_LOGMODE, 0
;
write"+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
;
end_it:
;
write" >>> Requirements Report"
;
FOR i = 0 to ut_req_array_size DO
  ut_pfindicate {cfe_requirements[i]} {ut_requirement[i]}
ENDDO
write" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
;
drop ut_requirement ; needed to clear global variables
drop ut_req_array_size ; needed to clear global variables
;
write "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
;
write"END of PROCEDURE to test EVS reset"
;                
ENDPROC
