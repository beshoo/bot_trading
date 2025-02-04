//+------------------------------------------------------------------+
//|                     TwoWayHedgingEA - Technical Documentation        |
#property copyright "Telegram: @deep2trade"
#property version   "2.00"
#property description "Deep2Trade is a cutting-edge Forex trading bot that employs a sophisticated Martingale strategy alongside robust risk management.\n"\
                     "Using technical analysis and dynamic stop loss methods, it fine-tunes trade entries and exits.\n"\
                     "Perfect for beginners and experts, it targets up to 79% profit potential."
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
/*
OVERVIEW:
This Expert Advisor implements a sophisticated two-phase hedging strategy with dynamic 
position scaling and synchronized take profit management. The EA operates in two distinct
phases with different trade management approaches in each phase, utilizing a complex
system of trade synchronization and TP management.

CRITICAL TECHNICAL DETAILS:

1. Take Profit Synchronization:
   Phase 1 - Independent TPs:
   * Each trade calculates its own TP: OpenPrice ± (CounterTradeTP * point_value)
   * TPs are not linked between trades
   * Updates affect individual trades only
   * Manual TP changes are respected
   * TP updates only occur when CounterTradeTP parameter changes
   
   Phase 2 - Synchronized TPs:
   * When settings change:
     1. Last trade's TP is recalculated first
     2. All other trades sync to match last trade
   * When last trade closes:
     - Its final TP becomes the sync target
     - All remaining trades update to match
   * Manual TP changes from mobile are detected and propagated
   * Mobile TP changes on last trade become the new sync target

2. Mobile Interaction Handling:
   Phase 1 Mobile Features:
   * Manual TP modifications are preserved
   * TPs only update when CounterTradeTP parameter changes
   * Individual trade TPs can be set independently
   * Changes persist until parameter update

   Phase 2 Mobile Features:
   * Last trade's TP changes are detected
   * Changes propagate to all other trades
   * Sync maintains even after mobile modifications
   * Last known TP preserved when last trade closes

3. TP Change Detection:
   * Continuous monitoring of TP values
   * Detection of mobile platform changes
   * Preservation of manual adjustments
   * Proper synchronization after changes

4. Trade Closure Handling:
   * Manual closure detection
   * Proper volume tracking maintenance
   * Phase reset on manual closure
   * Last known TP preservation

5. Phase Transition Logic:
   Phase 1 ? 2 (After TP Hit):
   * Identifies remaining trade direction
   * Sets scaling direction to match
   * Begins TP synchronization
   * Starts volume progression

   Phase 2 ? 1 (After Scale TP Hit):
   * Resets to initial state
   * Prepares for new counter-trades
   * Clears TP sync state
   * Maintains volume tracking

6. Volume Management:
   * Progression tracking via g_lastTradeVolume
   * Normalization: Round to symbol step size
   * Validation against broker limits
   * Scaling sequence preservation

7. Risk Management:
   * Total Loss Monitoring:
     - Continuously tracks floating losses in Phase 2
     - Compares against TotalLosses parameter
     - Triggers emergency closure when exceeded
   * Emergency Closure Process:
     - Updates all TPs to current market price
     - Forces immediate trade closure
     - Resets to Phase 1 with hold time
   * Loss Calculation:
     - Sums all negative profits
     - Only considers Phase 2 trades
     - Uses absolute values for consistency

ADDITIONAL CRITICAL TECHNICAL DETAILS:

1. Trade Sequence Dependencies:
   * Initial Trade Pair (Phase 1):
     - Both trades must be opened in sequence
     - First trade failure should prevent second trade
     - Volume must be identical for both trades
   * Scaling Sequence (Phase 2):
     - Each scale must complete before next evaluation
     - Failed scale attempts should not affect TP sync
     - Volume progression must maintain regardless of failed attempts

2. TP Synchronization Edge Cases:
   * When Last Trade Closes:
     - Its TP becomes the sync target before closure
     - All remaining trades must update before new trades
     - Failed updates must be logged but not block progression
   * During Parameter Updates:
     - All trades must sync to new settings
     - Updates must complete in specific order (last trade first)
     - Partial update failure must not break synchronization

3. Error Recovery Sequences:
   * Trade Context Busy:
     - Maximum retry attempts: 3
     - Delay between retries: 1000ms
     - Must maintain operation order during retries
   * Position Modification Disabled:
     - Must preserve intended TP values
     - Should not affect phase state
     - Must log but continue operation

4. Volume Calculation Precision:
   * Rounding Rules:
     - Always round to broker's volume step
     - Must handle different step sizes (0.01, 0.1, etc.)
     - Must prevent cumulative rounding errors
   * Validation Sequence:
     1. Calculate raw volume
     2. Normalize to step size
     3. Validate against min/max
     4. Adjust if necessary
     5. Final normalization

5. State Management Dependencies:
   * Phase Transition Requirements:
     - All TP updates must complete before phase change
     - Volume tracking must persist across transitions
     - Trade count must be validated before and after
   * Global Variable Usage:
     - g_lastTradeVolume must update only after successful trades
     - g_inPhase1 must change only after full transition
     - g_lastProfitTime must update immediately on profit

6. Time-Critical Operations:
   * Trade Hold Time:
     - Must start counting after profit is confirmed
     - Should not reset on failed operations
     - Must persist across EA restarts
   * Trading Hours:
     - Must complete current operation if hours end
     - Should not start new operation near boundary
     - Must handle midnight crossing

7. Position Selection Safety:
   * Ticket Validation Sequence:
     1. Check ticket existence
     2. Verify magic number
     3. Validate position type
     4. Confirm position is still open
   * History Operations:
     - Limited to last 60 seconds for performance
     - Must handle broker history limitations
     - Should not block main operations

8. Memory Management:
   * String Operations:
     - Use StringFormat for concatenation
     - Clear string variables after logging
     - Handle potential buffer overflows
   * Array Operations:
     - Proper array sizing for position operations
     - Clear arrays after use
     - Handle potential out-of-memory conditions

9. Broker-Specific Considerations:
   * Point Value Calculations:
     - Must handle both 4 and 5 digit brokers
     - Adjust multiplier based on symbol digits
     - Maintain precision across calculations
   * Volume Constraints:
     - Must respect broker's volume step size
     - Handle different min/max volumes per symbol
     - Prevent invalid volume progressions

10. Performance Optimization:
    * Position Selection:
      - Cache position data when possible
      - Minimize repeated position selections
      - Use ticket-based selection when available
    * Update Operations:
      - Batch TP updates when possible
      - Minimize redundant calculations
      - Cache point and digit values

11. Logging Optimization:
    * Critical vs Debug Logging:
      - Trade operations must always log
      - TP updates should log only on change
      - Errors must log with full context
    * Log Management:
      - Prevent excessive logging in loops
      - Include all relevant trade details
      - Maintain timestamp accuracy

DETAILED FUNCTIONALITY:

1. Phase Management:
   Phase 1 - Initial Hedging:
   * Opens two counter-positions (buy/sell) with equal volume (StartingVolume)
   * Each position has independent TP calculated from its open price
   * TPs are calculated as: OpenPrice ± (CounterTradeTP * point_value * points_multiplier)
   * Transitions to Phase 2 when either position hits TP
   * During Phase 1, TP updates are calculated independently for each trade

   Phase 2 - Dynamic Scaling:
   * Activates when one Phase 1 trade hits TP
   * Scales in direction of remaining trade using geometric progression
   * All trades in Phase 2 must maintain synchronized TPs
   * TP synchronization process:
     - Last trade's TP is used as the master TP value
     - All other trades are updated to match this TP
     - When last trade is closed, its TP becomes the new target for remaining trades
   * Returns to Phase 1 when scaled position hits TP

2. Volume Management:
   Initial Volume:
   * Defined by StartingVolume parameter
   * Must respect broker's MIN/MAX volume constraints
   * Rounded to symbol's volume step size

   Scaling Calculation:
   * Uses geometric progression: NewVolume = LastVolume * ((100 + ScalePercent)/100)
   * Volume validation process:
     - Checks against SYMBOL_VOLUME_MIN
     - Checks against SYMBOL_VOLUME_MAX
     - Rounds to SYMBOL_VOLUME_STEP
   * Maintains volume progression through g_lastTradeVolume global variable

3. Take Profit Management:
   Phase 1 TP Calculation:
   * Independent TPs for buy/sell positions
   * Formula: OpenPrice ± (CounterTradeTP * point_value * points_multiplier)
   * Handles broker digit variations (3/5 digits)
   * Updates allowed only during Phase 1

   Phase 2 TP Synchronization:
   * Master TP taken from last opened trade
   * Synchronization process:
     1. Updates last trade's TP first
     2. Propagates this TP to all other trades
     3. When last trade closes, its TP becomes new sync target
   * Prevents chart TP modifications via ChartSetInteger() flags

4. Trade Operation Safety:
   Position Selection:
   * Uses PositionSelectByTicket() for accurate position access
   * Validates magic number for each operation
   * Tracks position IDs for accurate trade management

   Error Handling:
   * Comprehensive error code mapping
   * Specific handling for common errors:
     - 4756 (Position modification disabled)
     - 4068 (Trade context busy)
     - 4069 (Too many requests)
   * Automatic retry logic with delays

5. Risk Management:
   Trade Limits:
   * MaxOpenTrades parameter enforces position limit
   * Validates new trades against current position count
   * Prevents scaling when limit reached

   Time Restrictions:
   * DailySchedule parameter format: "HH:MM-HH:MM"
   * EnableDailySchedule toggle for time restrictions
   * TradeHoldTime delay after profitable trades

6. UI and Chart Management:
   Chart Protection:
   * Disables manual TP modification via:
     ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false)
     ChartSetInteger(0, CHART_DRAG_TRADE_LEVELS, false)
   * Prevents user interference with trade management

7. State Management:
   Global Variables:
   * g_inPhase1: Current phase tracker
   * g_lastTradeVolume: Volume progression
   * g_lastProfitTime: Trade timing control
   * g_magicNumber: Trade identification

   State Transitions:
   * Phase 1 ? Phase 2: When first TP hit
   * Phase 2 ? Phase 1: When scaling TP hit
   * Volume progression maintained across phases

8. Logging System:
   Comprehensive Logging:
   * Trade operations (open, close, modify)
   * TP updates and synchronization
   * Error conditions with descriptions
   * Phase transitions
   * Volume calculations
   * Parameter updates

9. Critical Operations:
   TP Synchronization:
   * Atomic updates to prevent desynchronization
   * Validation before each TP modification
   * Error handling for failed updates

   Volume Progression:
   * Strict validation against broker limits
   * Precise rounding to prevent invalid volumes
   * Protection against excessive scaling

10. Trade Context Management:
    * Checks for trade context busy state
    * Implements delays for busy conditions
    * Validates trading permissions:
      - Terminal trading allowed
      - Expert trading allowed
      - Account trading allowed

11. Position Tracking:
    * Maintains accurate position count
    * Tracks trade closure and profit status
    * Monitors position modifications
    * Validates magic number for all operations

12. Market Condition Handling:
    * Spread monitoring capabilities
    * Point value adjustments
    * Broker-specific digit handling
    * Symbol-specific volume constraints

DEVELOPMENT CONSIDERATIONS:
1. TP Management Priority:
   * Phase 1: Independent TPs must be maintained
   * Phase 2: Synchronized TPs are critical
   * TP updates must be atomic and validated

2. Volume Management Priority:
   * Strict validation against broker limits
   * Precise calculation of scaling progression
   * Protection against invalid volumes

3. State Management Priority:
   * Clean phase transitions
   * Accurate position tracking
   * Proper error handling

4. Performance Considerations:
   * Minimize unnecessary updates
   * Efficient position selection
   * Optimized logging

DEBUGGING FOCUS AREAS:
1. TP Synchronization Issues:
   * Check Phase 2 TP update logic
   * Verify last trade TP propagation
   * Monitor TP modification errors

2. Volume Calculation Issues:
   * Verify scaling progression
   * Check volume normalization
   * Monitor broker limits

3. Phase Transition Issues:
   * Validate phase change triggers
   * Check remaining position handling
   * Monitor trade closure detection

4. Error Handling:
   * Track common error patterns
   * Monitor retry mechanisms
   * Verify error logging

This EA requires continuous monitoring of:
1. TP synchronization accuracy
2. Volume progression validity
3. Phase transition timing
4. Error handling effectiveness
5. Position tracking accuracy
*/

//+------------------------------------------------------------------+
//|                                              TwoWayHedgingEA.mq5   |
//|                                      Copyright 2024, Your Name      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// Input Parameters
input double StartingVolume = 0.01;       // Initial lot size
input group           "Target has to be greater than distance";

input int    CounterTradeTP = 5;         // Take profit in points
input int    FixedDistance = 3;          // Distance for scaling in points
input int    ScalePercent = 100;          // Scaling percentage (50 means increase by 50%)
input int    TradeHoldTime = 60;          // Hold time after profit (seconds)
input string DailySchedule = "09:00-17:00"; // Trading hours (format: "HH:MM-HH:MM")
input bool   EnableDailySchedule = false;   // Enable/Disable daily schedule
input int    MaxOpenTrades = 5;           // Maximum number of open trades allowed
input double TotalLosses = 100;           // Maximum allowed total losses in Phase 2 (in account currency)

// Global Variables
int g_magicNumber = 123456;
datetime g_lastProfitTime = 0;
bool g_inPhase1 = true;
double g_lastTradeVolume = 0;
static bool g_maxTradesWarningLogged = false;  // Static flag for max trades warning
static bool g_lastUpdateFailed = false;        // For TP update failures
static bool g_noMoneyErrorLogged = false;      // For no money errors
static bool g_posModifyErrorLogged = false;    // For position modification errors
static datetime g_lastErrorLogTime = 0;        // To control error log frequency
static double g_lastScalePrice = 0;  // Track the price of last scale in
static int g_lastKnownCounterTradeTP = 0;  // Track last known TP setting
static double g_lastSyncedTP = 0;  // Track the last synced TP value
static datetime g_lastTPCheck = 0;  // Track when we last checked TPs
static datetime g_lastTPUpdateLog = 0;  // Track when we last logged a TP update message
double g_lastKnownGoodTP = 0;  // Store the last known good TP value

//+------------------------------------------------------------------+
//| Logging Functions                                                  |
//+------------------------------------------------------------------+
/*
* LogAction
* Purpose: Primary logging function for general EA actions and events
* Parameters:
*   action (string) - Brief description of the action being logged
*   details (string) - Optional detailed information about the action
* Behavior:
*   - Formats timestamp with date and seconds
*   - Combines action and details into a single message
*   - Outputs to terminal using Print()
* Usage: General purpose logging for any EA action
*/
void LogAction(string action, string details="")
{
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    string message = StringFormat("[%s] %s %s", timestamp, action, details);
    Print(message);
}

/*
* LogTradeAction
* Purpose: Specialized logging for trade-related actions
* Parameters:
*   action (string) - Trade action description (open, modify, etc.)
*   ticket (ulong) - Trade ticket number
*   volume (double) - Trade volume
*   price (double) - Trade price
*   tp (double) - Take profit level
*   comment (string) - Trade comment
* Behavior:
*   - Retrieves position ID if available
*   - Formats comprehensive trade details
*   - Uses LogAction for output
* Usage: Called when opening or modifying trades
*/
void LogTradeAction(string action, ulong ticket, double volume, double price, double tp, string comment)
{
    ulong positionID = 0;
    if(PositionSelectByTicket(ticket))
        positionID = PositionGetInteger(POSITION_IDENTIFIER);
        
    string details = StringFormat("Ticket: %d, PositionID: %d, Volume: %.2f, Price: %.5f, TP: %.5f, Comment: %s", 
                                ticket, positionID, volume, price, tp, comment);
    LogAction(action, details);
}

/*
* LogTradeClose
* Purpose: Log details when a trade is closed
* Parameters:
*   ticket (ulong) - Ticket of closed trade
*   profit (double) - Profit/loss from the trade
* Behavior:
*   - Retrieves historical position ID
*   - Logs closure details including profit
* Usage: Called when a trade hits TP or is otherwise closed
*/
void LogTradeClose(ulong ticket, double profit)
{
    ulong positionID = 0;
    if(HistorySelectByPosition(ticket))
        positionID = HistoryOrderGetInteger(ticket, ORDER_POSITION_ID);
        
    string details = StringFormat("Ticket: %d, PositionID: %d, Profit: %.2f", ticket, positionID, profit);
    LogAction("Trade Closed", details);
}

/*
* LogError
* Purpose: Comprehensive error logging with descriptions
* Parameters:
*   action (string) - Action that caused the error
*   error (int) - Error code
* Behavior:
*   - Maps error codes to descriptive messages
*   - Handles common trading errors
*   - Implements delays for specific errors
* Usage: Called whenever an error occurs in trading operations
*/
void LogError(string action, int error)
{
    // Only log errors once every 60 seconds
    if(TimeCurrent() - g_lastErrorLogTime < 60)
        return;
        
    string error_desc = "";
    switch(error)
    {
        case 0:                     error_desc = "No error"; break;
        case 4001:                  error_desc = "Unexpected internal error"; break;
        case 4051:                  error_desc = "Invalid function parameter value"; break;
        case 4052:                  error_desc = "Invalid parameter in string function"; break;
        case 4053:                  error_desc = "String array error"; break;
        case 4054:                  error_desc = "Array error"; break;
        case 4055:                  error_desc = "Custom indicator error"; break;
        case 4056:                  error_desc = "Arrays incompatible"; break;
        case 4057:                  error_desc = "Global variables processing error"; break;
        case 4058:                  error_desc = "Global variable not found"; break;
        case 4059:                  error_desc = "Function not allowed in testing mode"; break;
        case 4060:                  error_desc = "Function not allowed"; break;
        case 4061:                  error_desc = "Send mail error"; break;
        case 4062:                  error_desc = "String parameter expected"; break;
        case 4063:                  error_desc = "Integer parameter expected"; break;
        case 4064:                  error_desc = "Double parameter expected"; break;
        case 4065:                  error_desc = "Array as parameter expected"; break;
        case 4066:                  error_desc = "Account data request error"; break;
        case 4067:                  error_desc = "Trade request error"; break;
        case 4068:                  error_desc = "Trade context busy"; break;
        case 4069:                  error_desc = "Too many requests"; break;
        case 4070:                  error_desc = "Trade timeout"; break;
        case 4071:                  error_desc = "Invalid price"; break;
        case 4072:                  error_desc = "Invalid ticket"; break;
        case 4073:                  error_desc = "Trade disabled"; break;
        case 4074:                  error_desc = "Not enough money"; break;
        case 4075:                  error_desc = "Price changed"; break;
        case 4076:                  error_desc = "Off quotes"; break;
        case 4077:                  error_desc = "Broker busy"; break;
        case 4078:                  error_desc = "Requote"; break;
        case 4079:                  error_desc = "Order locked"; break;
        case 4080:                  error_desc = "Buy orders only allowed"; break;
        case 4081:                  error_desc = "Too many requests"; break;
        case 4099:                  error_desc = "End of file"; break;
        case 4100:                  error_desc = "File error"; break;
        case 4101:                  error_desc = "Wrong file name"; break;
        case 4102:                  error_desc = "Too many opened files"; break;
        case 4103:                  error_desc = "Cannot open file"; break;
        case 4104:                  error_desc = "Incompatible access to file"; break;
        case 4105:                  error_desc = "No order selected"; break;
        case 4106:                  error_desc = "Unknown symbol"; break;
        case 4107:                  error_desc = "Invalid price parameter"; break;
        case 4108:                  error_desc = "Invalid ticket"; break;
        case 4109:                  error_desc = "Trade not allowed"; break;
        case 4110:                  error_desc = "Longs not allowed"; break;
        case 4111:                  error_desc = "Shorts not allowed"; break;
        case 4200:                  error_desc = "Object already exists"; break;
        case 4201:                  error_desc = "Unknown object property"; break;
        case 4202:                  error_desc = "Object does not exist"; break;
        case 4203:                  error_desc = "Unknown object type"; break;
        case 4204:                  error_desc = "No object name"; break;
        case 4205:                  error_desc = "Object coordinates error"; break;
        case 4206:                  error_desc = "No specified subwindow"; break;
        case 4207:                  error_desc = "Some object error"; break;
        case 4756:                  error_desc = "Position modification disabled"; break;
        default:                    error_desc = "Unknown error";
    }
    
    g_lastErrorLogTime = TimeCurrent();
    string details = StringFormat("Error %d: %s", error, error_desc);
    LogAction("ERROR in " + action, details);
    
    // Add delay if too frequent requests or trade context busy
    if(error == 4069 || error == 4068)
        Sleep(1000);
}

/*
* LogPhaseChange
* Purpose: Log transitions between Phase 1 and Phase 2
* Parameters:
*   isPhase1 (bool) - Whether switching to Phase 1
*   totalTrades (int) - Current number of open trades
* Behavior:
*   - Logs phase transition with trade count
*   - Provides context for state changes
* Usage: Called during phase transitions
*/
void LogPhaseChange(bool isPhase1, int totalTrades)
{
    string phase = isPhase1 ? "Phase 1" : "Phase 2";
    string details = StringFormat("Total trades: %d", totalTrades);
    LogAction("Switching to " + phase, details);
}

/*
* LogParameterUpdate
* Purpose: Track changes to EA parameters
* Parameters:
*   paramName (string) - Name of parameter being changed
*   oldValue (string) - Previous parameter value
*   newValue (string) - New parameter value
* Behavior:
*   - Logs parameter changes for tracking
* Usage: Called when EA parameters are modified
*/
void LogParameterUpdate(string paramName, string oldValue, string newValue)
{
    string details = StringFormat("%s changed from %s to %s", paramName, oldValue, newValue);
    LogAction("Parameter Update", details);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
/*
* OnInit
* Purpose: EA initialization and setup
* Behavior:
*   - Disables manual TP modification on chart
*   - Initializes EA with magic number
*   - Prints initial scaling sequence
* Returns: INIT_SUCCEEDED on successful initialization
* Usage: Called once when EA is loaded
*/
int OnInit()
{
    // Reset all static variables
    g_lastKnownCounterTradeTP = 0;
    g_lastUpdateFailed = false;
    g_posModifyErrorLogged = false;
    g_maxTradesWarningLogged = false;
    g_noMoneyErrorLogged = false;
    g_lastErrorLogTime = 0;
    g_lastScalePrice = 0;
    g_lastSyncedTP = 0;
    g_lastTPCheck = 0;
    g_lastTPUpdateLog = 0;
    g_lastProfitTime = 0;
    g_lastTradeVolume = 0;
    
    // Disable manual trading on chart
    ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, true);
    ChartSetInteger(0, CHART_DRAG_TRADE_LEVELS, false);
    
    // Print current state
    int totalTrades = CountEATrades();
    Print("OnInit - Current state:");
    Print("Total EA trades: ", totalTrades);
    
    // Determine initial phase based on trades
    g_inPhase1 = IsInPhase1();
    Print("Current Phase: ", g_inPhase1 ? "Phase 1" : "Phase 2");
    
    // Check all trades and their details
    Print("Current trades details:");
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double tp = PositionGetDouble(POSITION_TP);
            string type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            string comment = PositionGetString(POSITION_COMMENT);
            Print("Trade ", ticket, " - Type: ", type, ", Volume: ", volume, ", TP: ", tp, ", Comment: ", comment);
        }
    }
    
    // If in Phase 2, force TP sync
    if(!g_inPhase1 && totalTrades > 0)  // Changed condition to sync if any trades exist in Phase 2
    {
        Print("In Phase 2 with trades - forcing TP sync...");
        ForceTPSync();
    }
    
    // Initialize g_lastTradeVolume based on existing trades
    g_lastTradeVolume = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            double volume = PositionGetDouble(POSITION_VOLUME);
            if(volume > g_lastTradeVolume)
                g_lastTradeVolume = volume;
        }
    }
    
    // Only set to StartingVolume if we have no trades
    if(g_lastTradeVolume == 0)
    {
        g_lastTradeVolume = StartingVolume;
        LogAction("Volume Initialization", "No existing trades - using StartingVolume");
    }
    else
    {
        LogAction("Volume Initialization", StringFormat("Found existing trade volume: %.2f", g_lastTradeVolume));
    }
    
    LogAction("EA Initialized", StringFormat("Magic Number: %d", g_magicNumber));
    PrintScalingSequence();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clear all static variables
    g_lastKnownCounterTradeTP = 0;
    g_lastUpdateFailed = false;
    g_posModifyErrorLogged = false;
    g_maxTradesWarningLogged = false;
    g_noMoneyErrorLogged = false;
    g_lastErrorLogTime = 0;
    g_lastScalePrice = 0;
    g_lastSyncedTP = 0;
    g_lastTPCheck = 0;
    g_lastTPUpdateLog = 0;
    
    string reasonStr = "";
    switch(reason)
    {
        case REASON_PROGRAM:     reasonStr = "Program"; break;
        case REASON_REMOVE:      reasonStr = "Removed"; break;
        case REASON_RECOMPILE:   reasonStr = "Recompiled"; break;
        case REASON_CHARTCHANGE: reasonStr = "Chart changed"; break;
        case REASON_CHARTCLOSE:  reasonStr = "Chart closed"; break;
        case REASON_PARAMETERS:  reasonStr = "Parameters changed"; break;
        case REASON_ACCOUNT:     reasonStr = "Account changed"; break;
        default:                 reasonStr = "Unknown"; break;
    }
    
    LogAction("EA Deinitialized", StringFormat("Reason: %s", reasonStr));
}

//+------------------------------------------------------------------+
//| Print first 10 scaling volumes                                     |
//+------------------------------------------------------------------+
/*
* PrintScalingSequence
* Purpose: Calculate and display first 10 trade volumes
* Behavior:
*   - Uses StartingVolume and ScalePercent
*   - Shows geometric progression of volumes
*   - Helps validate scaling parameters
* Usage: Called during initialization
*/
void PrintScalingSequence()
{
    double volume = StartingVolume;
    Print("Scaling sequence for first 10 trades:");
    for(int i=1; i<=10; i++)
    {
        Print("Trade ", i, ": ", volume, " lots");
        // Calculate next volume using ScalePercent
        volume = NormalizeDouble(volume * ((100 + ScalePercent)/100.0), 2);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
/*
* OnTick
* Purpose: Main EA processing function
* Behavior:
*   - Checks trading hours and hold time
*   - Updates TPs for existing trades
*   - Manages Phase 1 or Phase 2 logic
* Usage: Called on each tick
*/
void OnTick()
{
    // Check if we're within trading hours
    if(EnableDailySchedule && !IsWithinTradingHours())
        return;
        
    // Check hold time after profit
    if(g_lastProfitTime > 0 && TimeCurrent() - g_lastProfitTime < TradeHoldTime)
    {
        static datetime lastHoldTimeLog = 0;
        if(TimeCurrent() - lastHoldTimeLog >= 60)  // Log only once per minute
        {
            LogAction("Hold Time Active", StringFormat("Waiting for %d seconds after Phase 2 profit", TradeHoldTime));
            lastHoldTimeLog = TimeCurrent();
        }
        return;
    }
    
    // Reset hold time logging flag when hold time expires
    if(g_lastProfitTime > 0 && TimeCurrent() - g_lastProfitTime >= TradeHoldTime)
    {
        g_lastProfitTime = 0;  // Reset the profit time
        LogAction("Hold Time Complete", "Resuming trading");
    }
    
    // Check for manual trade closure
    static int lastTradeCount = 0;
    int currentTradeCount = CountEATrades();
    
    // Handle trade count changes
    if(currentTradeCount < lastTradeCount)
    {
        // Trade was closed
        if(g_inPhase1)
        {
            // In Phase 1, if a trade is closed, switch to Phase 2 and prepare for scaling
            g_inPhase1 = false;
            
            // Get the remaining trade's type and volume for scaling
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
                ulong ticket = PositionGetTicket(i);
                if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
                {
                    ENUM_ORDER_TYPE remainingType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
                    double remainingVolume = PositionGetDouble(POSITION_VOLUME);
                    g_lastTradeVolume = remainingVolume;  // Use the remaining trade's volume for scaling
                    
                    // Calculate new volume with proper scaling
                    double newVolume = NormalizeDouble(g_lastTradeVolume * ((100 + ScalePercent)/100.0), 2);
                    
                    LogAction("Phase Change", StringFormat("Trade closed in Phase 1, switching to Phase 2. Current Volume: %.2f, Next Scale: %.2f", 
                             g_lastTradeVolume, newVolume));
                    
                    // Open new trade in the same direction as the remaining trade
                    if(OpenTrade(remainingType, newVolume, "Scale_In"))
                    {
                        g_lastTradeVolume = newVolume;  // Update last trade volume after successful scale
                        Sleep(50);  // Small delay to ensure new trade is processed
                        ForceTPSync();  // Force sync immediately after new scale trade
                    }
                    break;
                }
            }
        }
        else
        {
            // In Phase 2, only reset to Phase 1 if we have no trades left
            if(currentTradeCount == 0)
            {
                g_inPhase1 = true;
                g_lastProfitTime = TimeCurrent();  // Set hold time when Phase 2 completes
                g_lastScalePrice = 0;
                g_lastTradeVolume = StartingVolume;
                LogAction("Phase Reset", "No trades remaining, resetting to Phase 1");
                return;  // Return here to prevent immediate trade opening
            }
            else
            {
                // Still in Phase 2, find the largest volume among remaining trades
                double maxVolume = 0;
                for(int i = PositionsTotal() - 1; i >= 0; i--)
                {
                    ulong ticket = PositionGetTicket(i);
                    if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
                    {
                        double volume = PositionGetDouble(POSITION_VOLUME);
                        if(volume > maxVolume)
                            maxVolume = volume;
                    }
                }
                g_lastTradeVolume = maxVolume;  // Update last trade volume to the largest remaining volume
                LogAction("Phase 2 Trade Closed", StringFormat("Recalculating TPs for remaining trades. Current Volume: %.2f", g_lastTradeVolume));
                ForceTPSync();
            }
        }
    }
    
    lastTradeCount = currentTradeCount;
    
    // Add hold time check before starting Phase 1 trades
    if(g_inPhase1 && CountEATrades() == 0)
    {
        static datetime lastAttempt = 0;
        if(TimeCurrent() - lastAttempt < 1)  // Add 1-second delay between attempts
            return;
            
        lastAttempt = TimeCurrent();
        
        // Check if we're still in hold time
        if(g_lastProfitTime > 0 && TimeCurrent() - g_lastProfitTime < TradeHoldTime)
        {
            return;  // Don't open new trades during hold time
        }
        
        LogAction("Starting Phase 1", "Opening initial trades");
        ManagePhase1();  // Call only once
    }
    else
    {
        // Main trading logic with proper TP management
        if(g_inPhase1)
        {
            UpdateAllTakeProfiles();
            // No need to call ManagePhase1() here since we already have trades
        }
        else
        {
            // In Phase 2, sync TPs first, then manage trading
            if(CountEATrades() > 0)
            {
                ForceTPSync();  // Force sync every tick in Phase 2
                Sleep(50);  // Small delay after sync
                ManagePhase2();
            }
            else
            {
                // If we're in Phase 2 but have no trades, reset to Phase 1
                g_inPhase1 = true;
                g_lastScalePrice = 0;
                g_lastTradeVolume = StartingVolume;
                LogAction("Phase Reset", "No trades detected, resetting to Phase 1");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                      |
//+------------------------------------------------------------------+
/*
* IsWithinTradingHours
* Purpose: Validate if current time is within allowed trading hours
* Returns: bool - true if within trading hours
* Behavior:
*   - Parses DailySchedule parameter
*   - Compares current time against schedule
* Usage: Called before any trading operation
*/
bool IsWithinTradingHours()
{
    datetime current = TimeCurrent();
    string start = StringSubstr(DailySchedule, 0, 5);
    string end = StringSubstr(DailySchedule, 6, 5);
    
    datetime startTime = StringToTime(TimeToString(current, TIME_DATE) + " " + start);
    datetime endTime = StringToTime(TimeToString(current, TIME_DATE) + " " + end);
    
    return (current >= startTime && current <= endTime);
}

//+------------------------------------------------------------------+
//| Manage Phase 1 - Initial trades                                    |
//+------------------------------------------------------------------+
/*
* ManagePhase1
* Purpose: Handle Phase 1 trading logic
* Behavior:
*   - Opens initial counter-trades if none exist
*   - Transitions to Phase 2 when one trade hits TP
*   - Manages volume tracking
* Usage: Called when EA is in Phase 1
*/
void ManagePhase1()
{
    static datetime lastTradeTime = 0;
    int totalTrades = CountEATrades();
    
    // Add delay between trade attempts (at least 1 second)
    if(TimeCurrent() - lastTradeTime < 1)
        return;
        
    if(totalTrades == 0)
    {
        LogAction("Starting Phase 1", "Opening initial trades");
        
        // Open initial buy trade
        if(OpenTrade(ORDER_TYPE_BUY, StartingVolume, "Phase1_Buy"))
        {
            Sleep(50);  // Small delay between trades
            // Only open sell trade if buy trade was successful
            if(OpenTrade(ORDER_TYPE_SELL, StartingVolume, "Phase1_Sell"))
            {
                lastTradeTime = TimeCurrent();
                g_lastTradeVolume = StartingVolume;
            }
        }
    }
    else if(!IsInPhase1() && totalTrades >= 2)
    {
        // Switch to Phase 2 if we're not in Phase 1 and have enough trades
        LogPhaseChange(false, totalTrades);
        g_inPhase1 = false;
        ForceTPSync();  // Sync TPs when entering Phase 2
    }
}

//+------------------------------------------------------------------+
//| Get the type of the last trade                                     |
//+------------------------------------------------------------------+
/*
* GetLastTradeType
* Purpose: Determine the type of most recent trade
* Returns: ENUM_ORDER_TYPE - Type of last trade or WRONG_VALUE
* Behavior:
*   - Finds most recent trade by ticket
*   - Returns trade type (BUY/SELL)
* Usage: Used in phase transitions and trade management
*/
ENUM_ORDER_TYPE GetLastTradeType()
{
    ulong lastTicket = GetLastTradeTicket();
    if(!PositionSelectByTicket(lastTicket))
        return WRONG_VALUE;
        
    return (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
}

//+------------------------------------------------------------------+
//| Manage Phase 2 - Scaling trades                                    |
//+------------------------------------------------------------------+
/*
* ManagePhase2
* Purpose: Handle Phase 2 scaling logic
* Behavior:
*   - Checks trade limits
*   - Monitors for TP hits
*   - Manages scaling based on price movement
*   - Handles volume progression
* Usage: Called when EA is in Phase 2
*/
void ManagePhase2()
{
    // Add risk management check at the start of Phase 2 management
    CheckTotalLosses();
    
    // Check if maximum trades limit is reached
    int currentTrades = CountEATrades();
    if(currentTrades >= MaxOpenTrades)
    {
        if(!g_maxTradesWarningLogged)
        {
            LogAction("Scaling Skipped", StringFormat("Maximum trades limit (%d) reached", MaxOpenTrades));
            g_maxTradesWarningLogged = true;
        }
        return;
    }
    g_maxTradesWarningLogged = false;  // Reset the warning flag when below limit
    
    ulong lastTicket = GetLastTradeTicket();
    if(lastTicket == 0)
    {
        g_lastScalePrice = 0;  // Reset last scale price when no trades exist
        return;
    }
    
    // Check if last trade hit TP
    if(IsTradeClosedInProfit(lastTicket))
    {
        LogAction("Trade Closed in Profit", StringFormat("Ticket: %d", lastTicket));
        
        // Check if this was the last trade of Phase 2 (all trades closed)
        if(CountEATrades() == 0)
        {
            g_lastProfitTime = TimeCurrent();
            LogAction("Phase 2 Complete", "Setting hold time after all trades closed");
        }
        
        g_inPhase1 = true;
        g_lastScalePrice = 0;  // Reset last scale price when returning to Phase 1
        LogPhaseChange(true, CountEATrades());
        return;
    }
    
    // Check for adverse movement
    if(ShouldScaleIn(lastTicket))
    {
        LogAction("Scaling In", StringFormat("Base Ticket: %d", lastTicket));
        
        // Calculate new volume with proper scaling percentage
        double newVolume = NormalizeDouble(g_lastTradeVolume * ((100 + ScalePercent)/100.0), 2);
        
        // Validate volume before trying to open trade
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        
        if(newVolume < minVolume || newVolume > maxVolume)
        {
            LogAction("Volume Error", StringFormat("Volume %.2f outside allowed range [%.2f-%.2f]", 
                     newVolume, minVolume, maxVolume));
            return;
        }
        
        // Round to the nearest valid step size
        newVolume = NormalizeDouble(MathRound(newVolume / stepVolume) * stepVolume, 2);
        
        ENUM_ORDER_TYPE type = GetLastTradeType();
        if(type != WRONG_VALUE)
        {
            if(OpenTrade(type, newVolume, "Scale_In"))
            {
                g_lastTradeVolume = newVolume;  // Update last trade volume after successful scale
                g_lastScalePrice = PositionGetDouble(POSITION_PRICE_OPEN);  // Update last scale price ONLY after successful trade
                LogAction("Scale Success", StringFormat("Type: %s, NewVolume: %.2f, LastVolume updated", 
                         type == ORDER_TYPE_BUY ? "BUY" : "SELL", newVolume));
                Sleep(50);  // Small delay after trade
                ForceTPSync();  // Force sync immediately after new scale trade
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open new trade with enhanced error handling                        |
//+------------------------------------------------------------------+
/*
* OpenTrade
* Purpose: Execute new trade with comprehensive validation
* Parameters:
*   type (ENUM_ORDER_TYPE) - Trade direction (BUY/SELL)
*   volume (double) - Trade size
*   comment (string) - Trade comment
* Returns: bool - true if trade opened successfully
* Behavior:
*   - Validates trading conditions
*   - Checks volume constraints
*   - Calculates proper TP levels
*   - Handles trade execution
* Usage: Called when opening any new position
*/
bool OpenTrade(ENUM_ORDER_TYPE type, double volume, string comment)
{
    // Reset no money error flag at the start of each trading session or when conditions change
    if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) > AccountInfoDouble(ACCOUNT_MARGIN_INITIAL))
        g_noMoneyErrorLogged = false;
    
    // Check if maximum trades limit is reached
    if(CountEATrades() >= MaxOpenTrades)
    {
        LogAction("Trade Rejected", StringFormat("Maximum trades limit (%d) reached", MaxOpenTrades));
        return false;
    }
    
    // Check if trading is allowed
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
    {
        LogError("OpenTrade", 4073); // Trade disabled
        return false;
    }
    
    // Check if we can trade
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        LogError("OpenTrade", 4073); // Trade disabled
        return false;
    }
    
    // Check if automated trading is allowed
    if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
    {
        LogError("OpenTrade", 4073); // Trade disabled
        return false;
    }
    
    // Validate volume
    double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(volume < minVolume || volume > maxVolume)
    {
        LogAction("Volume Error", StringFormat("Volume %.2f outside allowed range [%.2f-%.2f]", 
                 volume, minVolume, maxVolume));
        return false;
    }
    
    // Round to the nearest valid step size
    volume = NormalizeDouble(MathRound(volume / stepVolume) * stepVolume, 2);
    
    // Check if trade context is busy
    if(IsTradeContextBusy())
    {
        LogError("OpenTrade", 4068); // Trade context busy
        return false;
    }
    
    double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Calculate TP correctly based on trade type
    double tp = (type == ORDER_TYPE_BUY) 
                ? price + (CounterTradeTP * SymbolInfoDouble(_Symbol, SYMBOL_POINT))  // BUY: Entry + TP
                : price - (CounterTradeTP * SymbolInfoDouble(_Symbol, SYMBOL_POINT)); // SELL: Entry - TP
    
    // Round TP to the correct number of digits
    tp = NormalizeDouble(tp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    // Get allowed filling modes for the symbol
    int filling = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = volume;
    request.type = type;
    request.price = price;
    request.tp = tp;
    request.deviation = 5;
    request.magic = g_magicNumber;
    request.comment = comment;
    
    // Set appropriate filling mode
    if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
    {
        request.type_filling = ORDER_FILLING_FOK;
    }
    else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
    {
        request.type_filling = ORDER_FILLING_IOC;
    }
    else
    {
        request.type_filling = ORDER_FILLING_RETURN;  // Default filling mode
    }
    
    bool success = OrderSend(request, result);
    
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        // Always update g_lastTradeVolume on successful trade
        g_lastTradeVolume = volume;
        g_noMoneyErrorLogged = false;
        
        LogAction("Volume Tracking", StringFormat("Updated g_lastTradeVolume to %.2f after %s trade", 
                 volume, type == ORDER_TYPE_BUY ? "BUY" : "SELL"));
                 
        LogTradeAction("Trade Opened", result.order, volume, price, tp, comment);
        
        // Log additional position details
        if(PositionSelectByTicket(result.order))
        {
            ulong positionID = PositionGetInteger(POSITION_IDENTIFIER);
            LogAction("Position Details", StringFormat("Type: %s, PositionID: %d, Volume: %.2f", 
                     type == ORDER_TYPE_BUY ? "BUY" : "SELL", positionID, volume));
        }
        return true;
    }
    else
    {
        int lastError = GetLastError();
        if(result.retcode == 10019 && !g_noMoneyErrorLogged)  // No money error
        {
            LogAction("Trade Failed", "Insufficient funds for further scaling");
            g_noMoneyErrorLogged = true;
        }
        else if(lastError == 4756 && !g_posModifyErrorLogged)  // Position modification disabled
        {
            LogError("OpenTrade", lastError);
            g_posModifyErrorLogged = true;
        }
        else if(lastError != 4756 && result.retcode != 10019)  // Other errors
        {
            LogError("OpenTrade", lastError);
            if(result.retcode != TRADE_RETCODE_DONE)
                LogAction("Trade Failed", StringFormat("RetCode: %d, Comment: %s", result.retcode, result.comment));
        }
        return false;
    }
}

//+------------------------------------------------------------------+
//| Update take profit levels with enhanced error handling             |
//+------------------------------------------------------------------+
/*
* UpdateAllTakeProfiles
* Purpose: Manage TP levels based on current phase
* Behavior:
* Phase 1:
*   - Updates TPs independently for each trade
*   - Calculates TPs based on individual open prices
* Phase 2:
*   - Updates last trade's TP first
*   - Synchronizes all other trades to match
*   - Handles broker-specific point calculations
* Usage: Called after trade operations and on tick
*/
void UpdateAllTakeProfiles()
{
    static double lastKnownTP = 0;
    static bool parameterChangeLogged = false;
    
    // Check if CounterTradeTP parameter has changed
    if(g_lastKnownCounterTradeTP != CounterTradeTP)
    {
        g_lastKnownCounterTradeTP = CounterTradeTP;
        g_lastUpdateFailed = false;
        g_posModifyErrorLogged = false;
        parameterChangeLogged = false;
    }
    
    // Get the point value and digits for proper TP calculation
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double points_multiplier = 1;
    
    if(digits == 3 || digits == 5)
        points_multiplier = 10;
    
    if(g_inPhase1)
    {
        bool anyUpdates = false;
        // Phase 1 logic - update TPs when CounterTradeTP changes
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                ENUM_ORDER_TYPE posType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
                double currentTP = PositionGetDouble(POSITION_TP);
                
                // Calculate new TP based on current CounterTradeTP
                double newTP = (posType == ORDER_TYPE_BUY) 
                              ? openPrice + (CounterTradeTP * point * points_multiplier)
                              : openPrice - (CounterTradeTP * point * points_multiplier);
                              
                newTP = NormalizeDouble(newTP, digits);
                
                // Only update if TP is different
                if(MathAbs(currentTP - newTP) > point)
                {
                    MqlTradeRequest request = {};
                    MqlTradeResult result = {};
                    
                    request.action = TRADE_ACTION_SLTP;
                    request.position = ticket;
                    request.symbol = _Symbol;
                    request.tp = newTP;
                    
                    bool success = OrderSend(request, result);
                    if(success && result.retcode == TRADE_RETCODE_DONE)
                    {
                        anyUpdates = true;
                        LogAction("TP Updated", StringFormat("Phase 1 - Ticket: %d, Type: %s, New TP: %.5f", 
                                 ticket, posType == ORDER_TYPE_BUY ? "BUY" : "SELL", newTP));
                    }
                    else if(!g_lastUpdateFailed && !g_posModifyErrorLogged)
                    {
                        if(result.retcode == 10025)  // No changes
                        {
                            g_lastUpdateFailed = true;
                        }
                        else if(GetLastError() == 4756)  // Position modification disabled
                        {
                            g_posModifyErrorLogged = true;
                            LogError("UpdateTP", 4756);
                        }
                        else
                        {
                            LogError("UpdateTP", GetLastError());
                            if(result.retcode != TRADE_RETCODE_DONE)
                                LogAction("TP Update Failed", StringFormat("RetCode: %d, Comment: %s", result.retcode, result.comment));
                        }
                    }
                }
            }
        }
        
        // Log parameter change only if updates were made
        if(anyUpdates && !parameterChangeLogged)
        {
            LogAction("TP Parameter Applied", StringFormat("CounterTradeTP updated to: %d", CounterTradeTP));
            parameterChangeLogged = true;
        }
    }
}

//+------------------------------------------------------------------+
//| Monitor and sync last trade TP to previous trades                  |
//+------------------------------------------------------------------+
void MonitorLastTradeTP()
{
    if(g_inPhase1)
        return;
        
    // Get current last trade
    ulong lastTicket = GetLastTradeTicket();
    if(lastTicket == 0)
        return;
        
    // If we can't select the position, return
    if(!PositionSelectByTicket(lastTicket))
        return;
        
    double lastTradeTP = PositionGetDouble(POSITION_TP);
    if(lastTradeTP == 0)
        return;
        
    // Force sync all other trades to match the last trade's TP
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket != lastTicket && 
           PositionSelectByTicket(ticket) && 
           PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            double currentTP = PositionGetDouble(POSITION_TP);
            
            // Only update if TP is different
            if(MathAbs(currentTP - lastTradeTP) > SymbolInfoDouble(_Symbol, SYMBOL_POINT))
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_SLTP;
                request.position = ticket;
                request.symbol = _Symbol;
                request.tp = lastTradeTP;
                
                bool success = OrderSend(request, result);
                if(success && result.retcode == TRADE_RETCODE_DONE)
                {
                    LogAction("TP Synced", StringFormat("Trade %d synced to TP: %.5f", ticket, lastTradeTP));
                }
                else
                {
                    LogError("TP Sync", GetLastError());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Helper functions                                                   |
//+------------------------------------------------------------------+
/*
* CountEATrades
* Purpose: Count current open trades managed by this EA
* Returns: int - Number of open trades
* Behavior:
*   - Filters by magic number
*   - Counts only positions, not pending orders
* Usage: Used for trade management and limits
*/
int CountEATrades()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
            count++;
    }
    return count;
}

/*
* GetLastTradeTicket
* Purpose: Find most recent trade ticket
* Returns: ulong - Ticket number or 0 if none found
* Behavior:
*   - Searches all positions
*   - Filters by magic number
*   - Uses position time to determine latest
* Usage: Critical for Phase 2 TP synchronization
*/
ulong GetLastTradeTicket()
{
    ulong lastTicket = 0;
    datetime lastTime = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            if(openTime > lastTime)
            {
                lastTime = openTime;
                lastTicket = ticket;
            }
        }
    }
    return lastTicket;
}

/*
* GetTradeInfo
* Purpose: Retrieve essential trade information
* Parameters:
*   ticket (ulong) - Trade ticket to query
*   openPrice (double&) - Reference for open price
*   type (ENUM_ORDER_TYPE&) - Reference for trade type
* Returns: bool - true if information retrieved successfully
* Usage: Used in trade management and TP calculations
*/
bool GetTradeInfo(ulong ticket, double &openPrice, ENUM_ORDER_TYPE &type)
{
    if(!PositionSelectByTicket(ticket))
        return false;
        
    openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
    return true;
}

/*
* IsTradeClosedInProfit
* Purpose: Check if specific trade closed with profit
* Parameters:
*   ticket (ulong) - Trade ticket to check
* Returns: bool - true if trade closed with profit
* Behavior:
*   - Checks recent history
*   - Verifies profit value
* Usage: Used for phase transitions and profit tracking
*/
bool IsTradeClosedInProfit(ulong ticket)
{
    HistorySelect(TimeCurrent() - 60, TimeCurrent());
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket)
        {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            if(profit > 0)
            {
                LogTradeClose(ticket, profit);
                return true;
            }
            return false;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calculate point difference between two prices for any symbol       |
//+------------------------------------------------------------------+
double CalculatePointDifference(const string symbol, double price1, double price2)
{
   // Calculate the raw price difference.
   double diff = price2 - price1;
   
   // Retrieve the minimal price increment (point) as reported by the broker.
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
   {
      Print("Error: Unable to determine the point value for symbol ", symbol);
      return 0.0;
   }
   
   // For precious metals (Gold, Silver), override the point if needed.
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0 ||
      StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
   {
      // For example, if you want to treat 0.01 price movement as 1 point:
      point = 0.01;
   }
   
   // Return the difference in "points"
   return diff / point;
}
//+------------------------------------------------------------------+
//| Should Scale In function using the new point calculation         |
//+------------------------------------------------------------------+
bool ShouldScaleIn(ulong ticket)
{
    // Add static variables for tracking last scale attempt
    static datetime lastScaleAttempt = 0;
    static double lastScalePrice = 0;
    
    // Check if money errors have been logged
    if(g_noMoneyErrorLogged)
        return false;
        
    // Change delay from 5 seconds to 500ms
    if(TimeCurrent() - lastScaleAttempt < 1)  // Changed from 5 to 1 second for datetime comparison
    {
        // For more precise timing, check milliseconds
        if(GetTickCount() - (lastScaleAttempt * 1000) < 500)  // 500ms delay
            return false;
    }
    
    if(!PositionSelectByTicket(ticket))
        return false;
        
    // Retrieve the order type and last trade's open price
    ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
    double lastTradePrice = PositionGetDouble(POSITION_PRICE_OPEN);
    
    // For BUY positions use the Bid, for SELL positions use the Ask
    double currentPrice = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Calculate the price move in points using our generic function
    double priceMove = CalculatePointDifference(_Symbol, lastTradePrice, currentPrice);
    
    // Log movement details every 60 seconds (optional)
    static datetime lastLogTime = 0;
    if(TimeCurrent() - lastLogTime >= 60)
    {
        LogAction("Movement :", StringFormat(
            "Vol: %.2f | Type: %s | Move: %.1f | Req: %d | LastPrice: %.2f | Current: %.2f",
            g_lastTradeVolume,
            (type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            priceMove,
            FixedDistance,
            lastTradePrice,
            currentPrice
        ));
        lastLogTime = TimeCurrent();
    }
    
    // Check direction and required distance
    bool directionOk = (type == ORDER_TYPE_BUY && currentPrice < lastTradePrice) ||
                      (type == ORDER_TYPE_SELL && currentPrice > lastTradePrice);
                      
    bool distanceOk = MathAbs(priceMove) >= FixedDistance;
    
    // Only update last scale attempt if we're actually going to scale
    if(directionOk && distanceOk)  // This is equivalent to if(MathAbs(priceMove) >= FixedDistance && directionOk)
    {
        // Add a small delay and recheck price to ensure stability
        Sleep(200);  // 200ms delay
        
        // Recheck price after delay
        double verifyPrice = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        double verifyMove = CalculatePointDifference(_Symbol, lastTradePrice, verifyPrice);
        
        // Verify the price movement is still valid after delay
        if(MathAbs(verifyMove) < FixedDistance)
        {
            LogAction("Scale Verification", "Price movement no longer valid after delay check");
            return false;
        }
        
        // Prevent scaling if price hasn't moved enough from last scale price
        if(lastScalePrice != 0)
        {
            double moveFromLastScale = CalculatePointDifference(_Symbol, lastScalePrice, currentPrice);
            if(MathAbs(moveFromLastScale) < FixedDistance)
                return false;
        }
        
        lastScaleAttempt = TimeCurrent();
        lastScalePrice = currentPrice;
        
        // Optional logging for scale condition met
        LogAction("Scale Condition Met", StringFormat(
            "Vol: %.2f | Type: %s | Move: %.1f | Req: %d | LastPrice: %.2f | Current: %.2f",
            g_lastTradeVolume,
            (type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            priceMove,
            FixedDistance,
            lastTradePrice,
            currentPrice
        ));
        
        // Calculate the new volume (using ScalePercent)
        double newVolume = NormalizeDouble(g_lastTradeVolume * ((100 + ScalePercent) / 100.0), 2);
        LogAction("Volume Calculation", StringFormat(
            "PositionID: %d, LastVolume: %.2f, ScalePercent: %d, NewVolume: %.2f",
            PositionGetInteger(POSITION_IDENTIFIER),
            g_lastTradeVolume,
            ScalePercent,
            newVolume
        ));
        
        // Validate volume against broker limits
        double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        
        if(newVolume < minVolume || newVolume > maxVolume)
        {
            LogAction("Volume Error", StringFormat(
                "Volume %.2f outside allowed range [%.2f - %.2f]", 
                newVolume, minVolume, maxVolume
            ));
            return false;
        }
        
        // Round to the nearest valid step
        newVolume = NormalizeDouble(MathRound(newVolume / stepVolume) * stepVolume, 2);
        
        // Attempt to open the new trade with the calculated volume
        if(OpenTrade(type, newVolume, "Scale_In"))
        {
            // Update global tracking variables after a successful scale-in
            g_lastTradeVolume = newVolume;
            g_lastScalePrice = currentPrice;
            LogAction("Scale Success", StringFormat(
                "New trade opened. PositionID: %d | Type: %s | Price: %.2f | NewVolume: %.2f",
                PositionGetInteger(POSITION_IDENTIFIER),
                (type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                currentPrice,
                newVolume
            ));
            Sleep(50);
            ForceTPSync();
            return true;
        }
    }
    
    // Safety check: Ensure g_lastTradeVolume is not zero
    if(g_lastTradeVolume == 0)
    {
        // If no trades exist, reset to the starting volume
        if(CountEATrades() == 0)
        {
            LogAction("Scale Error", "Last trade volume is zero - no trades exist, using StartingVolume");
            g_lastTradeVolume = StartingVolume;
        }
        else
        {
            LogAction("Scale Error", "Last trade volume is zero but trades exist - attempting to recover volume");
            // Try to recover volume from existing trades
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
                ulong ticket = PositionGetTicket(i);
                if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
                {
                    double volume = PositionGetDouble(POSITION_VOLUME);
                    if(volume > g_lastTradeVolume)
                        g_lastTradeVolume = volume;
                }
            }
        }
    }
    
    return false;
}



/*
* OpenCounterTrade
* Purpose: Open trade in opposite direction
* Parameters:
*   volume (double) - Trade size
* Behavior:
*   - Determines counter direction
*   - Opens trade with proper volume
* Usage: Used in hedging operations
*/
void OpenCounterTrade(double volume)
{
    ulong lastTicket = GetLastTradeTicket();
    if(!PositionSelectByTicket(lastTicket))
        return;
        
    ENUM_ORDER_TYPE lastType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
    ENUM_ORDER_TYPE counterType = (lastType == ORDER_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    
    OpenTrade(counterType, volume, "Counter_Trade");
}

/*
* IsTradeContextBusy
* Purpose: Check if trading system is available
* Returns: bool - true if trading not allowed
* Behavior:
*   - Checks MQL trade permissions
* Usage: Called before trade operations
*/
bool IsTradeContextBusy()
{
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
        return true;
    return false;
}

//+------------------------------------------------------------------+
//| Check total losses and manage risk                                 |
//+------------------------------------------------------------------+
/*
* CheckTotalLosses
* Purpose: Monitor total floating losses in Phase 2
* Behavior:
*   - Calculates total floating losses for Phase 2 trades
*   - If losses exceed TotalLosses parameter, closes all trades
*   - Updates all TPs to current market price for immediate closure
* Returns: void
* Usage: Called during Phase 2 management
*/
void CheckTotalLosses()
{
    if(g_inPhase1)
        return;
        
    double totalLoss = 0;
    
    // Calculate total floating losses
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit < 0)
                totalLoss += MathAbs(profit);
        }
    }
    
    // Check if total losses exceed threshold
    if(totalLoss > TotalLosses)
    {
        LogAction("Risk Management", StringFormat("Total losses (%.2f) exceeded maximum allowed (%.2f)", totalLoss, TotalLosses));
        CloseAllTrades();  // This will now handle the alert after closing positions
    }
}

//+------------------------------------------------------------------+
//| Force TP synchronization in Phase 2                                |
//+------------------------------------------------------------------+
void ForceTPSync()
{
    // Only proceed if we have trades in Phase 2
    int totalTrades = CountEATrades();
    
    if(totalTrades == 0)
        return;
    
    // Get current last trade
    ulong lastTicket = GetLastTradeTicket();
    
    double syncTP = 0;
    
    // Track positions that failed modification
    static CHashMap<ulong, datetime> failedPositions;
    
    // Clean up old failed positions (older than 5 minutes)
    datetime currentTime = TimeCurrent();
    ulong keysArray[];
    failedPositions.GetKeys(keysArray);
    
    for(int i = 0; i < ArraySize(keysArray); i++)
    {
        datetime failTime;
        if(failedPositions.TryGetValue(keysArray[i], failTime))
        {
            if(currentTime - failTime > 300) // 5 minutes
                failedPositions.Remove(keysArray[i]);
        }
    }
    
    // If we can find the last trade, get its TP
    if(lastTicket != 0 && PositionSelectByTicket(lastTicket))
    {
        double lastTradeTP = PositionGetDouble(POSITION_TP);
        ENUM_POSITION_TYPE lastTradeType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        
        // Always recalculate TP for the last trade based on its open price
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        double points_multiplier = (digits == 3 || digits == 5) ? 10 : 1;
        
        double newTP = (lastTradeType == POSITION_TYPE_BUY) 
                      ? lastOpenPrice + (CounterTradeTP * point * points_multiplier)
                      : lastOpenPrice - (CounterTradeTP * point * points_multiplier);
                      
        newTP = NormalizeDouble(newTP, digits);
        
        // Update last trade's TP if it's different
        if(MathAbs(lastTradeTP - newTP) > point)
        {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_SLTP;
            request.position = lastTicket;
            request.symbol = _Symbol;
            request.tp = newTP;
            request.magic = g_magicNumber;
            
            bool success = OrderSend(request, result);
            
            if(success && result.retcode == TRADE_RETCODE_DONE)
            {
                Print("Successfully updated last trade TP");
                syncTP = newTP;
            }
            else
            {
                int error = GetLastError();
                if(error == 4756)
                {
                    failedPositions.Add(lastTicket, currentTime);
                    LogAction("TP Sync", StringFormat("Position %d modification disabled - skipping", lastTicket));
                }
                else
                {
                    Print("Failed to update last trade TP. Error: ", error);
                }
                return;  // Don't proceed if we can't update the last trade
            }
        }
        else
        {
            syncTP = lastTradeTP;  // Use current TP if no update needed
        }
    }
    else
    {
        return;
    }
    
    // Now sync all other trades to match the target TP
    int updatedTrades = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket != lastTicket && 
           PositionSelectByTicket(ticket) && 
           PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            // Skip positions that recently failed modification
            if(failedPositions.ContainsKey(ticket))
                continue;
                
            double currentTP = PositionGetDouble(POSITION_TP);
            
            // Only update if TP is different
            if(MathAbs(currentTP - syncTP) > SymbolInfoDouble(_Symbol, SYMBOL_POINT))
            {
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_SLTP;
                request.position = ticket;
                request.symbol = _Symbol;
                request.tp = syncTP;
                request.magic = g_magicNumber;
                
                bool success = OrderSend(request, result);
                
                if(success && result.retcode == TRADE_RETCODE_DONE)
                {
                    updatedTrades++;
                    Print("Successfully synced trade ", ticket, " TP to: ", syncTP);
                }
                else
                {
                    int error = GetLastError();
                    if(error == 4756)
                    {
                        failedPositions.Add(ticket, currentTime);
                        LogAction("TP Sync", StringFormat("Position %d modification disabled - skipping", ticket));
                    }
                    else
                    {
                        Print("Failed to sync trade ", ticket, ". Error: ", error);
                    }
                }
            }
        }
    }
}

// Add this class definition at the top of the file, after the includes
template<typename TKey, typename TValue>
class CHashMap
{
private:
    TKey m_keys[];
    TValue m_values[];
    
public:
    void Add(TKey key, TValue value)
    {
        int size = ArraySize(m_keys);
        ArrayResize(m_keys, size + 1);
        ArrayResize(m_values, size + 1);
        m_keys[size] = key;
        m_values[size] = value;
    }
    
    bool Remove(TKey key)
    {
        int size = ArraySize(m_keys);
        for(int i = 0; i < size; i++)
        {
            if(m_keys[i] == key)
            {
                for(int j = i; j < size - 1; j++)
                {
                    m_keys[j] = m_keys[j + 1];
                    m_values[j] = m_values[j + 1];
                }
                ArrayResize(m_keys, size - 1);
                ArrayResize(m_values, size - 1);
                return true;
            }
        }
        return false;
    }
    
    bool ContainsKey(TKey key)
    {
        int size = ArraySize(m_keys);
        for(int i = 0; i < size; i++)
        {
            if(m_keys[i] == key)
                return true;
        }
        return false;
    }
    
    bool TryGetValue(TKey key, TValue &value)
    {
        int size = ArraySize(m_keys);
        for(int i = 0; i < size; i++)
        {
            if(m_keys[i] == key)
            {
                value = m_values[i];
                return true;
            }
        }
        return false;
    }
    
    void GetKeys(TKey &keys[])
    {
        ArrayResize(keys, ArraySize(m_keys));
        ArrayCopy(keys, m_keys);
    }
    
    void Clear()
    {
        ArrayResize(m_keys, 0);
        ArrayResize(m_values, 0);
    }
};

// Add new function for phase detection
bool IsInPhase1()
{
    int buyCount = 0;
    int sellCount = 0;
    bool hasNonStartingVolume = false;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double volume = PositionGetDouble(POSITION_VOLUME);
            string comment = PositionGetString(POSITION_COMMENT);
            
            // Check if this is a Phase 1 trade
            bool isPhase1Trade = (StringFind(comment, "Phase1") >= 0);
            
            if(type == POSITION_TYPE_BUY && isPhase1Trade)
                buyCount++;
            else if(type == POSITION_TYPE_SELL && isPhase1Trade)
                sellCount++;
                
            // Check if volume matches starting volume
            if(MathAbs(volume - StartingVolume) > 0.001)  // Using small epsilon for float comparison
                hasNonStartingVolume = true;
        }
    }
    
    // We're in Phase 1 if:
    // 1. We have exactly one buy and one sell trade
    // 2. All trades have starting volume
    return (buyCount == 1 && sellCount == 1 && !hasNonStartingVolume);
} 

// Add this function to the file
void CloseAllTrades()
{
    CTrade trade;
    trade.SetExpertMagicNumber(g_magicNumber);
    
    // Log the emergency closure first, without Alert
    double totalLoss = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit < 0)
                totalLoss += MathAbs(profit);
        }
    }
    
    LogAction("Emergency Closure", StringFormat("Total losses: %.2f - Closing all positions", totalLoss));
    
    // First pass: Set all TPs to current market price
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double marketPrice = (type == POSITION_TYPE_BUY) ? 
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            trade.PositionModify(ticket, 0, marketPrice); // Set SL=0 and TP=market price
        }
    }
    
    // Small delay to allow TP modifications to process
    Sleep(50);
    
    // Second pass: Close any remaining positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
        {
            if(trade.PositionClose(ticket))
            {
                LogAction("Position Closed", StringFormat("Ticket: %d closed successfully", ticket));
            }
            else 
            {
                LogError("Position Close", GetLastError());
            }
        }
    }
    
    // Reset relevant global variables
    g_inPhase1 = true;
    g_lastScalePrice = 0;
    g_lastTradeVolume = StartingVolume;
    g_lastProfitTime = TimeCurrent();
    
    // Send alert after positions are closed
    string alertMessage = StringFormat("WARNING: Total losses (%.2f) exceeded maximum allowed.\nAll positions have been closed!", totalLoss);
    Alert(alertMessage);
    
    // Stop the EA
    ExpertRemove();
}
