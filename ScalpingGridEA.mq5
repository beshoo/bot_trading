//+------------------------------------------------------------------+
//|                                                   ScalpingGridEA.mq5 |
//|                                  Copyright 2024, MetaQuotes Software |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>        // Include for trading operations
#include <Trade\DealInfo.mqh>     // Include for deal information

//+------------------------------------------------------------------+
//| Enums                                                              |
//+------------------------------------------------------------------+
enum ENUM_TRADING_HOURS
{
    Off,     // Off
    On       // On
};

// Input Parameters
input double   StartingVolume = 0.01;     // Initial trade size in lots
input int      CounterTradeTP = 50;       // Take Profit in points
input int      FixedDistance = 50;        // Distance for scaling in points
input double   ScalePercent = 50;         // Scaling percentage (50 = 50%)
input int      TradeHoldTime = 5;         // Cooldown period in minutes
input int      ScalingDelay = 10;         // Delay between scales (seconds)
input ENUM_TRADING_HOURS UseTradingHours = Off;  // Trading Hours Restriction
input string   DailyStartTime = "09:00";  // Trading session start (24h format)
input string   DailyEndTime = "24:00";    // Trading session end (24h format)
input int      MaxTrades = 5;             // Maximum number of trades allowed
input double   MaxLossUSD = 500;          // Maximum loss in USD before stopping
input bool     StopOnMaxLoss = true;      // Stop EA when max loss is reached

// Global Variables
int g_magic = 123456;  // Magic number for trade identification
datetime g_lastTradeTime = 0;  // Time of last trade closure
bool g_isWaiting = false;      // Cooldown period flag
double g_lastTradeVolume = 0;  // Volume of the last opened trade
int g_totalTrades = 0;         // Total number of open trades
CTrade         trade;             // Trading object
CDealInfo      deal;             // Deal information object
datetime g_lastScalingTime = 0;  // Time of last scaling operation
bool g_scalingInProgress = false; // Flag to prevent multiple scaling operations
bool g_isStoppedOnLoss = false;  // Flag to indicate if EA is stopped due to max loss
int g_prevCounterTradeTP = 0;     // Store previous TP value
int g_prevFixedDistance = 0;      // Store previous Fixed Distance value
double g_prevScalePercent = 0;    // Store previous Scale Percent value
double g_prevMaxLossUSD = 0;      // Store previous Max Loss value
int g_prevMaxTrades = 0;          // Store previous Max Trades value
double g_prevStartingVolume = 0;  // Store previous Starting Volume value
double g_lastScaledPrice = 0;    // Price at which last scaling occurred
int g_prevScalingDelay = 0;      // Store previous Scaling Delay value
bool g_initialPairOpen = false;    // Flag to track if we're in initial pair stage
bool g_readyForScaling = false;    // Flag to indicate we're ready to monitor for scaling

//+------------------------------------------------------------------+
//| Print scaling progression                                          |
//+------------------------------------------------------------------+
void PrintScalingProgression()
{
    Print("\n=== SCALING PROGRESSION ===");
    Print("Starting Volume: ", StartingVolume);
    Print("Scale Percent: ", ScalePercent, "%");
    
    double volume = StartingVolume;
    
    Print("\nScaling Steps (Growth from Starting Volume):");
    Print("Step 0 (Initial): ", volume, " (100% of start)");
    
    for(int i = 1; i <= 20; i++)
    {
        volume = CalculateNewVolume(volume);
        double percentOfStart = (volume / StartingVolume) * 100;
        
        Print("Step ", i, ": ", 
              "\tVolume: ", DoubleToString(volume, 2),
              "\tIncrease: +", DoubleToString(ScalePercent, 1), "%",
              "\tPercent of Start: ", DoubleToString(percentOfStart, 1), "%");
    }
    
    Print("\nAfter 20 scales:");
    Print("Final Volume: ", DoubleToString(volume, 2), 
          " (", DoubleToString((volume / StartingVolume) * 100, 1), "% of starting volume)");
    Print("=========================\n");
}

//+------------------------------------------------------------------+
//| Calculate total floating profit/loss                               |
//+------------------------------------------------------------------+
double CalculateTotalFloatingPL()
{
    double totalPL = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetInteger(POSITION_MAGIC) == g_magic)
            {
                totalPL += PositionGetDouble(POSITION_PROFIT);
            }
        }
    }
    
    return totalPL;
}

//+------------------------------------------------------------------+
//| Close positions by tickets                                        |
//+------------------------------------------------------------------+
void ClosePositionsByTickets(const ulong &tickets[], const double &volumes[])
{
    if(ArraySize(tickets) == 0) return;
    
    // Create arrays for batch closing
    MqlTradeRequest requests[];
    MqlTradeResult results[];
    
    // Prepare close requests for all positions
    for(int i = 0; i < ArraySize(tickets); i++)
    {
        if(PositionSelectByTicket(tickets[i]))
        {
            ArrayResize(requests, i + 1);
            ArrayResize(results, i + 1);
            
            requests[i].action = TRADE_ACTION_DEAL;
            requests[i].position = tickets[i];
            requests[i].symbol = _Symbol;
            requests[i].volume = volumes[i];
            requests[i].deviation = 5;
            requests[i].magic = g_magic;
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                requests[i].type = ORDER_TYPE_SELL;
                requests[i].price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            }
            else
            {
                requests[i].type = ORDER_TYPE_BUY;
                requests[i].price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            }
        }
    }
    
    // Send all close requests simultaneously
    for(int i = 0; i < ArraySize(requests); i++)
    {
        if(!OrderSendAsync(requests[i], results[i]))
        {
            Print("Failed to close position ", tickets[i], " Error: ", GetLastError());
        }
    }
    
    Print("All positions close requests sent simultaneously");
}

//+------------------------------------------------------------------+
//| Collect all EA positions                                          |
//+------------------------------------------------------------------+
void CollectEAPositions(ulong &tickets[], double &volumes[])
{
    ArrayResize(tickets, 0);
    ArrayResize(volumes, 0);
    int posCount = 0;
    
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == g_magic)
            {
                ArrayResize(tickets, posCount + 1);
                ArrayResize(volumes, posCount + 1);
                tickets[posCount] = ticket;
                volumes[posCount] = PositionGetDouble(POSITION_VOLUME);
                posCount++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    ulong tickets[];
    double volumes[];
    
    CollectEAPositions(tickets, volumes);
    ClosePositionsByTickets(tickets, volumes);
    g_totalTrades = 0;
}

//+------------------------------------------------------------------+
//| Check for maximum loss                                            |
//+------------------------------------------------------------------+
bool CheckMaxLoss()
{
    if(!StopOnMaxLoss || g_isStoppedOnLoss) return false;
    
    double totalPL = CalculateTotalFloatingPL();
    
    if(totalPL <= -MaxLossUSD)
    {
        Print("Maximum loss of $", MaxLossUSD, " reached. Current loss: $", MathAbs(totalPL));
        CloseAllPositions();
        g_isStoppedOnLoss = true;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Count current open positions                                      |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetInteger(POSITION_MAGIC) == g_magic)
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                      |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    // If trading hours are disabled, always return true
    if(UseTradingHours == Off) return true;
    
    datetime current = TimeCurrent();
    string currentTime = TimeToString(current, TIME_MINUTES);
    
    bool isWithin = (StringCompare(currentTime, DailyStartTime) >= 0 && 
                    StringCompare(currentTime, DailyEndTime) <= 0);
                    
    static datetime lastTimeCheck = 0;
    if(current - lastTimeCheck >= 60) // Print every minute
    {
        if(UseTradingHours == On)
            Print("Current Time: ", currentTime, ", Trading allowed: ", isWithin);
        lastTimeCheck = current;
    }
    
    return isWithin;
}

//+------------------------------------------------------------------+
//| Calculate new trade volume based on scaling                        |
//+------------------------------------------------------------------+
double CalculateNewVolume(double lastVolume)
{
    // Calculate new volume according to scaling formula
    double newVolume = lastVolume + (lastVolume * ScalePercent / 100.0);
    return NormalizeVolume(newVolume);
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler                                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
    // Check if this is a deal update
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
    
    // Get the deal ticket
    ulong dealTicket = trans.deal;
    
    // Select the deal and check if it belongs to our EA
    if(!HistoryDealSelect(dealTicket)) return;
    if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != g_magic) return;
    
    // Check if this is a position close
    long entryValue = 0, reasonValue = 0;
    
    if(!HistoryDealGetInteger(dealTicket, DEAL_ENTRY, entryValue)) return;
    if(!HistoryDealGetInteger(dealTicket, DEAL_REASON, reasonValue)) return;
    
    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)entryValue;
    ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)reasonValue;
    
    // Get the deal type and volume
    ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
    double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
    double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
    
    // If this is a position close
    if(entry == DEAL_ENTRY_OUT)
    {
        Print("Position closed. Type: ", EnumToString(dealType), 
              " Volume: ", dealVolume,
              " Profit: ", dealProfit,
              " Reason: ", EnumToString(reason),
              " Entry: ", EnumToString(entry),
              " Price: ", HistoryDealGetDouble(dealTicket, DEAL_PRICE),
              " Ticket: ", dealTicket);
        
        // Log additional details about the closed position
        double openPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
        double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
        Print("Trade Details - Open Price: ", openPrice,
              " Close Price: ", closePrice,
              " Points Moved: ", MathAbs(closePrice - openPrice) / _Point);
        
        // Update total trades count
        g_totalTrades = CountOpenPositions();
        
        // Only proceed if closed by TP and in profit
        if(reason == DEAL_REASON_TP && dealProfit > 0)
        {
            Print("Trade closed by TP in profit, proceeding with normal logic...");
            
            // Create arrays to store position tickets and volumes for batch closing
            ulong tickets[];
            double volumes[];
            
            // First collect ALL positions BEFORE checking anything
            CollectEAPositions(tickets, volumes);
            
            // Find if this was the last scaled trade (highest volume)
            bool wasLastScaledTrade = true;  // Assume it was the last until proven otherwise
            double closedVolume = dealVolume;
            
            // Check if any remaining position has higher volume
            for(int i = 0; i < ArraySize(volumes); i++)
            {
                if(volumes[i] > closedVolume)
                {
                    wasLastScaledTrade = false;
                    break;
                }
            }
            
            // If this was a scaled trade (volume > StartingVolume) AND was the last scaled trade
            if(dealVolume > StartingVolume && wasLastScaledTrade)
            {
                Print("Last scaled trade closed at TP in profit (volume: ", dealVolume, "). Closing all remaining positions simultaneously...");
                
                // Close all remaining positions
                CloseAllPositions();
                
                g_lastTradeTime = TimeCurrent();
                g_isWaiting = true;
                g_scalingInProgress = false;
                g_lastScaledPrice = 0;  // Reset scaling price
                int waitMinutes = TradeHoldTime;
                Print("All positions close requests sent simultaneously. Waiting for ", waitMinutes, " minutes before starting new cycle...");
                return;  // Exit and wait for cooldown
            }
            // If this was one of the initial trades
            else if(dealVolume == StartingVolume)
            {
                Print("Initial trade closed at TP. Opening counter trade with scaling...");
                
                // Calculate new scaled volume for counter trade
                double newVolume = CalculateNewVolume(dealVolume);
                Print("Opening counter trade with scaling. Volume: ", dealVolume, " to ", newVolume, 
                      " (", ScalePercent, "% increase)");
                
                // When we see DEAL_TYPE_BUY in closing deal, it means a SELL position was closed
                // So we need to open a BUY counter trade
                ENUM_ORDER_TYPE counterType = dealType == DEAL_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
                
                Print("Opening counter trade. Type: ", EnumToString(counterType),
                      " Volume: ", newVolume,
                      " (Counter to closed ", EnumToString(dealType), " deal)");
                
                // Verify we have the correct position count
                g_totalTrades = CountOpenPositions();
                Print("Current open positions before counter trade: ", g_totalTrades);
                
                // Open counter trade with scaled volume - no delay for first counter trade
                if(OpenTrade(counterType, newVolume, false))  // false = don't check delay
                {
                    Print("Counter trade opened successfully with scaled volume: ", newVolume,
                          " Ticket: ", trade.ResultOrder(),
                          " Current positions: ", CountOpenPositions());
                    g_lastScaledPrice = 0;  // Reset scaling price for new monitoring
                    g_readyForScaling = true;  // Now we can start monitoring for scaling
                    g_lastScalingTime = TimeCurrent();  // Set this after opening the trade
                }
                else
                {
                    int error = GetLastError();
                    Print("Failed to open counter trade. Error code: ", error);
                    Print("Failed trade details - Type: ", EnumToString(counterType),
                          " Volume: ", newVolume,
                          " Current positions: ", CountOpenPositions());
                }
                
                // Reset scaling flags but maintain the scaling time
                g_scalingInProgress = false;
                g_isWaiting = false;  // Allow scaling to begin
                Print("Counter trade cycle complete, monitoring for scaling");
            }
        }
        else
        {
            Print("Trade closed but not by TP in profit. Reason: ", EnumToString(reason),
                  " Profit: ", dealProfit,
                  " - Not proceeding with counter trade logic");
        }
    }
}

//+------------------------------------------------------------------+
//| Check if there's enough free margin to open a trade               |
//+------------------------------------------------------------------+
bool CheckMarginBeforeTrade(ENUM_ORDER_TYPE orderType, double volume)
{
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double margin;
    if(!OrderCalcMargin(orderType, _Symbol, volume, price, margin))
    {
        Print("Failed to calculate margin. Error: ", GetLastError());
        return false;
    }
    
    double freemargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    if(margin > freemargin)
    {
        Print("Not enough free margin to open trade. Required: ", margin, ", Available: ", freemargin);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Open new trade                                                     |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE orderType, double volume, bool checkDelay = true)
{
    // Only check scaling delay if this is not an initial trade AND checkDelay is true
    if(checkDelay && volume > StartingVolume && TimeCurrent() - g_lastScalingTime < ScalingDelay)
    {
        Print("Waiting for scaling delay (", ScalingDelay, " seconds) before opening new trade");
        return false;
    }
    
    // Verify current position count
    g_totalTrades = CountOpenPositions();
    
    // Check if we've reached maximum trades
    if(g_totalTrades >= MaxTrades)
    {
        Print("Maximum number of trades (", MaxTrades, ") reached. Cannot open new trade.");
        return false;
    }
    
    // Check margin before attempting to open trade
    if(!CheckMarginBeforeTrade(orderType, volume))
    {
        Print("Insufficient margin for trade volume: ", volume);
        return false;
    }
    
    volume = NormalizeDouble(volume, 2);  // Normalize the volume to 2 decimal places
    
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tp = (orderType == ORDER_TYPE_BUY) ? price + CounterTradeTP * _Point 
                                             : price - CounterTradeTP * _Point;
    
    Print("Opening ", EnumToString(orderType), " trade at price: ", DoubleToString(price, _Digits),
          " TP: ", DoubleToString(tp, _Digits),
          " (", CounterTradeTP, " points = ", CounterTradeTP * _Point, " movement)",
          " Current positions: ", g_totalTrades);
    
    // Reset error code before attempting trade
    ResetLastError();
    
    if(!trade.PositionOpen(_Symbol, orderType, volume, price, 0, tp, "ScalpingGridEA"))
    {
        int error = GetLastError();
        Print("Error opening trade. Error code: ", error);
        return false;
    }
    
    g_lastTradeVolume = volume;
    g_totalTrades++;
    return true;
}

//+------------------------------------------------------------------+
//| Normalize volume according to symbol settings                      |
//+------------------------------------------------------------------+
double NormalizeVolume(double volume)
{
    double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    volume = MathRound(volume / step) * step;
    volume = MathMax(min, MathMin(max, volume));
    
    return NormalizeDouble(volume, 2);
}

//+------------------------------------------------------------------+
//| Check for scaling conditions                                       |
//+------------------------------------------------------------------+
void CheckScalingConditions()
{
    // Only check for scaling if we're ready (after initial TP hit)
    if(!g_readyForScaling) return;
    
    // Only proceed if we have active trades
    if(g_totalTrades < 1) return;
    
    // Check if we've reached maximum trades
    if(g_totalTrades >= MaxTrades) return;
    
    // Find the last opened trade
    ulong lastTicket = 0;
    datetime lastOpenTime = 0;
    double lastOpenPrice = 0;
    ENUM_POSITION_TYPE lastPosType = POSITION_TYPE_BUY;
    double lastVolume = 0;
    
    // First pass: find the last trade
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetInteger(POSITION_MAGIC) == g_magic)
            {
                datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
                if(openTime > lastOpenTime)
                {
                    lastOpenTime = openTime;
                    lastTicket = ticket;
                    lastOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                    lastPosType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                    lastVolume = PositionGetDouble(POSITION_VOLUME);
                }
            }
        }
    }
    
    // Only proceed with scaling if the last trade volume is greater than starting volume
    // This ensures we don't scale during the initial pair stage
    if(lastVolume <= StartingVolume) return;
    
    // If we found the last trade, check its movement
    if(lastTicket > 0)
    {
        double currentPrice = lastPosType == POSITION_TYPE_BUY ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                            
        // Calculate adverse movement in points
        double points = 0;
        
        if(lastPosType == POSITION_TYPE_BUY)
        {
            // For BUY, adverse movement is when price goes down
            points = (currentPrice < lastOpenPrice) ? (lastOpenPrice - currentPrice) / _Point : 0;
        }
        else
        {
            // For SELL, adverse movement is when price goes up
            points = (currentPrice > lastOpenPrice) ? (currentPrice - lastOpenPrice) / _Point : 0;
        }
        
        // Log the movement
        static datetime lastLogTime = 0;
        if(TimeCurrent() - lastLogTime >= 5)  // Log every 5 seconds
        {
            Print("Last Trade Position ", lastTicket, 
                  " Adverse Movement: ", DoubleToString(points, 1),
                  " points of ", FixedDistance, " required",
                  " Type: ", EnumToString(lastPosType),
                  " OpenPrice: ", DoubleToString(lastOpenPrice, _Digits),
                  " CurrentPrice: ", DoubleToString(currentPrice, _Digits));
            lastLogTime = TimeCurrent();
        }
        
        // Check if enough time has passed since last scaling
        if(TimeCurrent() - g_lastScalingTime < ScalingDelay)
        {
            return;
        }
        
        // Check if we've moved enough points from the last scaling price
        if(g_lastScaledPrice != 0)
        {
            double pointsFromLastScale = 0;
            if(lastPosType == POSITION_TYPE_BUY)
            {
                pointsFromLastScale = (currentPrice < g_lastScaledPrice) ? 
                                    (g_lastScaledPrice - currentPrice) / _Point : 0;
            }
            else
            {
                pointsFromLastScale = (currentPrice > g_lastScaledPrice) ? 
                                    (currentPrice - g_lastScaledPrice) / _Point : 0;
            }
            
            if(pointsFromLastScale < FixedDistance)
            {
                return;
            }
        }
        
        // Scale if price moves against us by FixedDistance points
        if(points >= FixedDistance && !g_scalingInProgress)
        {
            g_scalingInProgress = true;
            
            ENUM_ORDER_TYPE orderType = (lastPosType == POSITION_TYPE_BUY) ? 
                                       ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            
            // Get the last trade's volume for scaling
            if(PositionSelectByTicket(lastTicket))
            {
                double currentVolume = PositionGetDouble(POSITION_VOLUME);
                double newVolume = CalculateNewVolume(currentVolume);
                
                Print("Attempting to scale trade. Current Points: ", points,
                      " Required: ", FixedDistance,
                      " Current Volume: ", currentVolume,
                      " New Volume: ", newVolume);
                
                if(OpenTrade(orderType, newVolume))
                {
                    g_lastScalingTime = TimeCurrent();
                    g_lastScaledPrice = currentPrice;
                    Print("Scaling trade opened. Direction: ", EnumToString(orderType), 
                          " Volume: ", newVolume, 
                          " Adverse Points: ", points);
                }
            }
            
            g_scalingInProgress = false;
        }
    }
}

//+------------------------------------------------------------------+
//| Update take profits for all open positions                        |
//+------------------------------------------------------------------+
void UpdateAllTakeProfits()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByTicket(PositionGetTicket(i)))
        {
            if(PositionGetInteger(POSITION_MAGIC) == g_magic)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                // Calculate new TP
                double newTP = (posType == POSITION_TYPE_BUY) ? 
                             openPrice + CounterTradeTP * _Point : 
                             openPrice - CounterTradeTP * _Point;
                
                // Modify the position's TP
                if(!trade.PositionModify(PositionGetTicket(i), 0, newTP))
                {
                    Print("Failed to update TP for position ", PositionGetTicket(i), 
                          ". Error: ", GetLastError());
                }
                else
                {
                    Print("Updated TP for position ", PositionGetTicket(i), 
                          " to ", DoubleToString(newTP, _Digits));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check for settings changes                                        |
//+------------------------------------------------------------------+
void CheckSettingsChanges()
{
    bool settingsChanged = false;
    bool tpChanged = false;
    string changes = "";
    
    // Check StartingVolume
    if(StartingVolume != g_prevStartingVolume)
    {
        changes += StringFormat("Starting Volume changed from %.2f to %.2f\n", 
                              g_prevStartingVolume, StartingVolume);
        g_prevStartingVolume = StartingVolume;
        settingsChanged = true;
    }
    
    // Check CounterTradeTP
    if(CounterTradeTP != g_prevCounterTradeTP)
    {
        changes += StringFormat("Take Profit changed from %d to %d points\n", 
                              g_prevCounterTradeTP, CounterTradeTP);
        g_prevCounterTradeTP = CounterTradeTP;
        settingsChanged = true;
        tpChanged = true;
    }
    
    // Check FixedDistance
    if(FixedDistance != g_prevFixedDistance)
    {
        changes += StringFormat("Fixed Distance changed from %d to %d points\n", 
                              g_prevFixedDistance, FixedDistance);
        g_prevFixedDistance = FixedDistance;
        settingsChanged = true;
    }
    
    // Check ScalePercent
    if(ScalePercent != g_prevScalePercent)
    {
        changes += StringFormat("Scale Percent changed from %.2f to %.2f\n", 
                              g_prevScalePercent, ScalePercent);
        g_prevScalePercent = ScalePercent;
        settingsChanged = true;
    }
    
    // Check MaxLossUSD
    if(MaxLossUSD != g_prevMaxLossUSD)
    {
        changes += StringFormat("Max Loss changed from %.2f to %.2f USD\n", 
                              g_prevMaxLossUSD, MaxLossUSD);
        g_prevMaxLossUSD = MaxLossUSD;
        settingsChanged = true;
    }
    
    // Check MaxTrades
    if(MaxTrades != g_prevMaxTrades)
    {
        changes += StringFormat("Max Trades changed from %d to %d\n", 
                              g_prevMaxTrades, MaxTrades);
        g_prevMaxTrades = MaxTrades;
        settingsChanged = true;
    }
    
    // Check ScalingDelay
    if(ScalingDelay != g_prevScalingDelay)
    {
        changes += StringFormat("Scaling Delay changed from %d to %d seconds\n", 
                              g_prevScalingDelay, ScalingDelay);
        g_prevScalingDelay = ScalingDelay;
        settingsChanged = true;
    }
    
    // If any settings changed, apply changes and log them
    if(settingsChanged)
    {
        Print("=== Settings Changed ===");
        Print(changes);
        Print("Current open positions: ", g_totalTrades);
        
        // If TP changed, update all positions
        if(tpChanged)
        {
            Print("Updating Take Profits for all positions...");
            for(int i = 0; i < PositionsTotal(); i++)
            {
                if(PositionSelectByTicket(PositionGetTicket(i)))
                {
                    if(PositionGetInteger(POSITION_MAGIC) == g_magic)
                    {
                        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                        
                        // Calculate new TP based on current settings
                        double newTP = (posType == POSITION_TYPE_BUY) ? 
                                     openPrice + CounterTradeTP * _Point : 
                                     openPrice - CounterTradeTP * _Point;
                        
                        // Modify the position
                        if(!trade.PositionModify(PositionGetTicket(i), 0, newTP))
                        {
                            Print("Failed to update position ", PositionGetTicket(i), 
                                  ". Error: ", GetLastError());
                        }
                        else
                        {
                            Print("Updated position ", PositionGetTicket(i),
                                  " Type: ", EnumToString(posType),
                                  " Volume: ", PositionGetDouble(POSITION_VOLUME),
                                  " OpenPrice: ", DoubleToString(openPrice, _Digits),
                                  " New TP: ", DoubleToString(newTP, _Digits),
                                  " Old TP: ", DoubleToString(PositionGetDouble(POSITION_TP), _Digits));
                        }
                    }
                }
            }
        }
        
        // Check max loss with new settings
        CheckMaxLoss();
        
        Print("=== Settings Update Complete ===");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime lastCheck = 0;
    datetime current = TimeCurrent();
    
    // Throttle tick processing
    if(current <= lastCheck) return;
    lastCheck = current;
    
    // Check for settings changes
    CheckSettingsChanges();
    
    // Check if EA is stopped due to max loss
    if(g_isStoppedOnLoss)
    {
        static datetime lastStopMsg = 0;
        if(current - lastStopMsg >= 60)  // Print every minute
        {
            Print("EA is stopped due to maximum loss being reached.");
            lastStopMsg = current;
        }
        return;
    }
    
    // Update total trades count
    g_totalTrades = CountOpenPositions();
    
    // Check for maximum loss
    if(CheckMaxLoss()) return;
    
    // Check if we're within trading hours
    if(!IsWithinTradingHours())
    {
        Print("Outside trading hours. Current trades: ", g_totalTrades);
        return;
    }
        
    // Check if we're in cooldown period
    if(g_isWaiting)
    {
        int remainingSeconds = (int)(TradeHoldTime * 60 - (TimeCurrent() - g_lastTradeTime));
        if(remainingSeconds > 0)
        {
           //Print("In cooldown period. ", remainingSeconds, " seconds remaining");
            return;
        }
        g_isWaiting = false;
        Print("Cooldown period ended");
    }
    
    // If no trades are open, start new cycle
    if(g_totalTrades == 0 && !g_isStoppedOnLoss)
    {
        Print("No open trades. Attempting to open initial hedge pair...");
        
        if(OpenTrade(ORDER_TYPE_BUY, StartingVolume))
            Print("Buy position opened successfully. Ticket: ", trade.ResultOrder());
        else
            Print("Failed to open Buy position. Error: ", GetLastError());
            
        if(OpenTrade(ORDER_TYPE_SELL, StartingVolume))
            Print("Sell position opened successfully. Ticket: ", trade.ResultOrder());
        else
            Print("Failed to open Sell position. Error: ", GetLastError());
            
        if(g_totalTrades == 2)
        {
            Print("Successfully opened initial hedge pair");
            g_initialPairOpen = true;
            g_readyForScaling = false;  // Reset scaling flag
        }
        else
            Print("Failed to open complete hedge pair. Current trades: ", g_totalTrades);
            
        return;
    }
    
    // Check for scaling conditions only if we're ready
    if(!g_isStoppedOnLoss && g_readyForScaling)
        CheckScalingConditions();
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Validate inputs
    if(StartingVolume <= 0 || CounterTradeTP <= 0 || FixedDistance <= 0 || ScalePercent <= 0 || MaxLossUSD <= 0)
    {
        Print("Invalid input parameters!");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    trade.SetExpertMagicNumber(g_magic);
    g_isStoppedOnLoss = false;
    g_totalTrades = CountOpenPositions();
    
    Print("=== EA INITIALIZATION ===");
    Print("Magic Number: ", g_magic);
    Print("Starting Volume: ", StartingVolume);
    Print("Counter Trade TP: ", CounterTradeTP, " points (", CounterTradeTP * _Point, " price movement)");
    Print("Fixed Distance: ", FixedDistance, " points (", FixedDistance * _Point, " price movement)");
    Print("Scale Percent: ", ScalePercent);
    Print("Current Open Positions: ", g_totalTrades);
    Print("Symbol: ", _Symbol);
    Print("Point Size: ", _Point);
    Print("Digits: ", _Digits);
    Print("Example: 30 points = ", 30 * _Point, " price movement");
    Print("======================\n");
    
    // Print scaling progression
    Print("\n=== SCALING PROGRESSION ===");
    Print("Starting Volume: ", StartingVolume);
    Print("Scale Percent: ", ScalePercent, "%");
    
    double volume = StartingVolume;
    
    Print("\nScaling Steps (Growth from Starting Volume):");
    Print("Step 0 (Initial): ", volume, " (100% of start)");
    
    for(int i = 1; i <= 20; i++)
    {
        volume = CalculateNewVolume(volume);
        double percentOfStart = (volume / StartingVolume) * 100;
        
        Print("Step ", i, ": ", 
              "\tVolume: ", DoubleToString(volume, 2),
              "\tIncrease: +", DoubleToString(ScalePercent, 1), "%",
              "\tPercent of Start: ", DoubleToString(percentOfStart, 1), "%");
    }
    
    Print("\nAfter 20 scales:");
    Print("Final Volume: ", DoubleToString(volume, 2));
    Print("=========================\n");
    
    // Check if settings have changed and update positions if needed
    bool settingsChanged = false;
    
    if(CounterTradeTP != g_prevCounterTradeTP)
    {
        Print("Take Profit changed from ", g_prevCounterTradeTP, " to ", CounterTradeTP, " points");
        settingsChanged = true;
    }
    
    if(FixedDistance != g_prevFixedDistance)
    {
        Print("Fixed Distance changed from ", g_prevFixedDistance, " to ", FixedDistance, " points");
        settingsChanged = true;
    }
    
    if(ScalePercent != g_prevScalePercent)
    {
        Print("Scale Percent changed from ", g_prevScalePercent, " to ", ScalePercent);
        settingsChanged = true;
    }
    
    // Store new values
    g_prevStartingVolume = StartingVolume;
    g_prevCounterTradeTP = CounterTradeTP;
    g_prevFixedDistance = FixedDistance;
    g_prevScalePercent = ScalePercent;
    g_prevMaxLossUSD = MaxLossUSD;
    g_prevMaxTrades = MaxTrades;
    
    // Initialize scaling delay
    g_prevScalingDelay = ScalingDelay;
    
    // If settings changed and we have open positions, update them
    if(settingsChanged && g_totalTrades > 0)
    {
        Print("Settings changed, updating open positions...");
        
        // Update all positions with new settings
        for(int i = 0; i < PositionsTotal(); i++)
        {
            if(PositionSelectByTicket(PositionGetTicket(i)))
            {
                if(PositionGetInteger(POSITION_MAGIC) == g_magic)
                {
                    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                    double oldTP = PositionGetDouble(POSITION_TP);
                    
                    // Calculate new TP based on current settings
                    double newTP = (posType == POSITION_TYPE_BUY) ? 
                                 openPrice + CounterTradeTP * _Point : 
                                 openPrice - CounterTradeTP * _Point;
                    
                    // Modify the position
                    if(!trade.PositionModify(PositionGetTicket(i), 0, newTP))
                    {
                        Print("Failed to update position ", PositionGetTicket(i), 
                              ". Error: ", GetLastError());
                    }
                    else
                    {
                        Print("Updated position ", PositionGetTicket(i),
                              " Type: ", EnumToString(posType),
                              " Volume: ", PositionGetDouble(POSITION_VOLUME),
                              " OpenPrice: ", DoubleToString(openPrice, _Digits),
                              " Old TP: ", DoubleToString(oldTP, _Digits),
                              " New TP: ", DoubleToString(newTP, _Digits));
                    }
                }
            }
        }
        Print("Position updates complete");
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up code here if needed
} 