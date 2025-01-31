//+------------------------------------------------------------------+
//|                     TwoWayHedgingEA - Technical Documentation        |
//+------------------------------------------------------------------+
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
   
   Phase 2 - Synchronized TPs:
   * When settings change:
     1. Last trade's TP is recalculated first
     2. All other trades sync to match last trade
   * When last trade closes:
     - Its final TP becomes the sync target
     - All remaining trades update to match
   * Manual TP changes are blocked

2. Phase Transition Logic:
   Phase 1 → 2 (After TP Hit):
   * Identifies remaining trade direction
   * Sets scaling direction to match
   * Begins TP synchronization
   * Starts volume progression

   Phase 2 → 1 (After Scale TP Hit):
   * Resets to initial state
   * Prepares for new counter-trades
   * Clears TP sync state
   * Maintains volume tracking

3. Volume Management:
   * Progression tracking via g_lastTradeVolume
   * Normalization: Round to symbol step size
   * Validation against broker limits
   * Scaling sequence preservation

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
   * Uses geometric progression: NewVolume = LastVolume * (1 + ScalePercent/100)
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
   * Phase 1 → Phase 2: When first TP hit
   * Phase 2 → Phase 1: When scaling TP hit
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
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property strict

// Input Parameters
input double StartingVolume = 0.01;       // Initial lot size
input int    CounterTradeTP = 30;         // Take profit in points
input int    FixedDistance = 30;          // Distance for scaling in points
input int    ScalePercent = 100;          // Scaling percentage
input int    TradeHoldTime = 60;          // Hold time after profit (seconds)
input string DailySchedule = "09:00-17:00"; // Trading hours (format: "HH:MM-HH:MM")
input bool   EnableDailySchedule = true;   // Enable/Disable daily schedule
input int    MaxOpenTrades = 5;           // Maximum number of open trades allowed

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
    // Disable manual trading on chart
    ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, true);
    ChartSetInteger(0, CHART_DRAG_TRADE_LEVELS, false);
    
    LogAction("EA Initialized", StringFormat("Magic Number: %d", g_magicNumber));
    
    // Print initial scaling sequence
    PrintScalingSequence();
    
    return(INIT_SUCCEEDED);
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
        volume = NormalizeDouble(volume + (volume * ScalePercent / 100), 2);
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
    if(TimeCurrent() - g_lastProfitTime < TradeHoldTime)
        return;
        
    // Update TPs for existing trades if needed
    UpdateAllTakeProfiles();
    
    // Main trading logic
    if(g_inPhase1)
        ManagePhase1();
    else
        ManagePhase2();
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
    int totalTrades = CountEATrades();
    
    if(totalTrades == 0)
    {
        LogAction("Starting Phase 1", "Opening initial trades");
        // Open initial buy and sell trades
        OpenTrade(ORDER_TYPE_BUY, StartingVolume, "Phase1_Buy");
        OpenTrade(ORDER_TYPE_SELL, StartingVolume, "Phase1_Sell");
        g_lastTradeVolume = StartingVolume;
    }
    else if(totalTrades == 1)
    {
        // Get the remaining trade's type
        ulong lastTicket = GetLastTradeTicket();
        if(PositionSelectByTicket(lastTicket))
        {
            LogPhaseChange(false, totalTrades);
            // One trade hit TP, switch to Phase 2
            g_inPhase1 = false;
            double newVolume = NormalizeDouble(g_lastTradeVolume + (g_lastTradeVolume * ScalePercent / 100), 2);
            
            // Get the type of the remaining trade and scale in that direction
            ENUM_ORDER_TYPE remainingType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
            LogAction("Phase 2 Start", StringFormat("Remaining trade type: %s, Scaling in same direction", 
                     remainingType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
            
            // Open new trade in the same direction as the remaining trade
            OpenTrade(remainingType, newVolume, "Counter_Trade");
        }
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
        return;
        
    // Check if last trade hit TP
    if(IsTradeClosedInProfit(lastTicket))
    {
        LogAction("Trade Closed in Profit", StringFormat("Ticket: %d", lastTicket));
        g_lastProfitTime = TimeCurrent();
        g_inPhase1 = true;
        LogPhaseChange(true, CountEATrades());
        return;
    }
    
    // Check for adverse movement
    if(ShouldScaleIn(lastTicket))
    {
        LogAction("Scaling In", StringFormat("Base Ticket: %d", lastTicket));
        double newVolume = NormalizeDouble(g_lastTradeVolume + (g_lastTradeVolume * ScalePercent / 100), 2);
        
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
                Sleep(100);  // Small delay to ensure trade is fully processed
                UpdateAllTakeProfiles();
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
                                           
    // Get the point value and digits for proper TP calculation
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double points_multiplier = 1;
    
    // Adjust points multiplier based on digits
    if(digits == 3 || digits == 5)
        points_multiplier = 10;
        
    double tp = (type == ORDER_TYPE_BUY) ? price + (CounterTradeTP * point * points_multiplier)
                                        : price - (CounterTradeTP * point * points_multiplier);
                                        
    // Round TP to the correct number of digits
    tp = NormalizeDouble(tp, digits);
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = volume;
    request.type = type;
    request.price = price;
    request.tp = tp;
    request.deviation = 5;
    request.magic = g_magicNumber;
    request.comment = comment;
    
    bool success = OrderSend(request, result);
    
    if(success && result.retcode == TRADE_RETCODE_DONE)
    {
        g_lastTradeVolume = volume;
        g_noMoneyErrorLogged = false;  // Reset on successful trade
        LogTradeAction("Trade Opened", result.order, volume, price, tp, comment);
        
        // Log additional position details
        if(PositionSelectByTicket(result.order))
        {
            ulong positionID = PositionGetInteger(POSITION_IDENTIFIER);
            LogAction("Position Details", StringFormat("Type: %s, PositionID: %d", 
                     type == ORDER_TYPE_BUY ? "BUY" : "SELL", positionID));
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
    
    // Reset error flags if TP has changed
    if(lastKnownTP != PositionGetDouble(POSITION_TP))
    {
        g_lastUpdateFailed = false;
        g_posModifyErrorLogged = false;
    }
    
    // Get the point value and digits for proper TP calculation
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double points_multiplier = 1;
    
    // Adjust points multiplier based on digits
    if(digits == 3 || digits == 5)
        points_multiplier = 10;
    
    if(g_inPhase1)
    {
        // Phase 1 logic remains the same - update TPs independently
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                ENUM_ORDER_TYPE posType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
                
                double newTP = (posType == ORDER_TYPE_BUY) 
                              ? openPrice + (CounterTradeTP * point * points_multiplier)
                              : openPrice - (CounterTradeTP * point * points_multiplier);
                              
                newTP = NormalizeDouble(newTP, digits);
                
                double currentTP = PositionGetDouble(POSITION_TP);
                if(currentTP != newTP)  // Only update if TP actually changed
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
                        LogAction("TP Updated", StringFormat("Phase 1 - Ticket: %d, PositionID: %d, Type: %s, New TP: %.5f", 
                                 ticket, PositionGetInteger(POSITION_IDENTIFIER), 
                                 posType == ORDER_TYPE_BUY ? "BUY" : "SELL", newTP));
                    }
                    else if(!g_lastUpdateFailed && !g_posModifyErrorLogged)
                    {
                        if(result.retcode == 10025)  // No changes
                        {
                            g_lastUpdateFailed = true;
                            LogAction("TP Update Skipped", "No changes needed");
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
    }
    else
    {
        // Phase 2 - First update last trade's TP, then sync all others
        ulong lastTicket = GetLastTradeTicket();
        if(lastTicket == 0)
            return;
            
        if(!PositionSelectByTicket(lastTicket))
            return;
            
        // Calculate new TP for last trade based on its open price
        double lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        ENUM_ORDER_TYPE lastType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
        
        double newLastTP = (lastType == ORDER_TYPE_BUY) 
                          ? lastOpenPrice + (CounterTradeTP * point * points_multiplier)
                          : lastOpenPrice - (CounterTradeTP * point * points_multiplier);
                          
        newLastTP = NormalizeDouble(newLastTP, digits);
        
        // Only proceed if TP actually changed
        if(newLastTP != lastKnownTP)
        {
            lastKnownTP = newLastTP;
            g_lastUpdateFailed = false;  // Reset error state when attempting new TP
            
            // Update last trade's TP first
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_SLTP;
            request.position = lastTicket;
            request.symbol = _Symbol;
            request.tp = newLastTP;
            
            bool success = OrderSend(request, result);
            if(success && result.retcode == TRADE_RETCODE_DONE)
            {
                LogAction("Last Trade TP Updated", StringFormat("Phase 2 - Ticket: %d, Type: %s, New TP: %.5f", 
                         lastTicket, lastType == ORDER_TYPE_BUY ? "BUY" : "SELL", newLastTP));
                         
                // Now sync all other trades to this new TP
                for(int i = PositionsTotal() - 1; i >= 0; i--)
                {
                    ulong ticket = PositionGetTicket(i);
                    if(ticket != lastTicket && PositionSelectByTicket(ticket) && 
                       PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
                    {
                        ENUM_ORDER_TYPE posType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
                        double currentTP = PositionGetDouble(POSITION_TP);
                        
                        if(currentTP != newLastTP)
                        {
                            request.position = ticket;
                            request.tp = newLastTP;
                            
                            success = OrderSend(request, result);
                            if(success && result.retcode == TRADE_RETCODE_DONE)
                            {
                                LogAction("TP Synced", StringFormat("Phase 2 - Ticket: %d, Type: %s, New TP: %.5f", 
                                         ticket, posType == ORDER_TYPE_BUY ? "BUY" : "SELL", newLastTP));
                            }
                        }
                    }
                }
            }
            else if(!g_lastUpdateFailed && !g_posModifyErrorLogged)
            {
                if(result.retcode == 10025)  // No changes
                {
                    g_lastUpdateFailed = true;
                    LogAction("TP Update Skipped", "No changes needed");
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
                        LogAction("Last Trade TP Update Failed", StringFormat("RetCode: %d, Comment: %s", 
                                result.retcode, result.comment));
                    g_lastUpdateFailed = true;
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
                g_lastProfitTime = TimeCurrent(); // Set the hold time when profit is confirmed
                return true;
            }
            return false;
        }
    }
    return false;
}

/*
* ShouldScaleIn
* Purpose: Determine if conditions met for scaling
* Parameters:
*   ticket (ulong) - Base trade ticket
* Returns: bool - true if should scale in
* Behavior:
*   - Checks price movement against FixedDistance
*   - Considers trade direction
* Usage: Called in Phase 2 for scaling decisions
*/
bool ShouldScaleIn(ulong ticket)
{
    // Don't attempt scaling if we've already logged a no money error
    if(g_noMoneyErrorLogged)
        return false;
        
    if(!PositionSelectByTicket(ticket))
        return false;
        
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
    double currentPrice = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) 
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                                  
    if(type == ORDER_TYPE_BUY)
        return (openPrice - currentPrice) >= FixedDistance * _Point;
    else
        return (currentPrice - openPrice) >= FixedDistance * _Point;
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