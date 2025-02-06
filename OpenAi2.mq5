//+------------------------------------------------------------------+
//|                                              Saer 29-10-2023.mq5   |
//|                              Copyright 2023,beshoo@gmail.com.      |
//|                              Ai Boot                               |
//+------------------------------------------------------------------+
#property copyright "beshoo@gmail.com"
#property version   "1.00"
#property description "AI-Powered Forex Trading Expert Advisor\n"\
                     "Features: AI Analysis, Multi-Timeframe Pattern Recognition, Advanced Risk Management\n"\
                     "Capabilities: Real-Time Market Analysis, Dynamic Position Sizing, Auto Stop-Loss/Take-Profit\n"\
                     "Requirements: API Key, Stable Internet, MT5 Platform\n"\
                     "Copyright 2024."
//#property icon      "\\Images\\ai_trading.ico"  // Optional: if you have an icon

#include <JAson.mqh>
#include <Trade/Trade.mqh>
#include <Indicators/Indicator.mqh>

// Add these constants at the top
#define MAIN_LINE 0
#define SIGNAL_LINE 1
#define VOLUME_TICK 0
#define STO_PRICE_CLOSE 0
#define HISTORY_SIZE 100  // Add this back
#define CHECK_HANDLE(handle) if(handle==INVALID_HANDLE) { Print(__FUNCTION__," failed to create handle"); return; }
#define CHECK_BUFFER(result) if(result<=0) { Print(__FUNCTION__," failed to copy buffer"); return; }

// Update these constants at the top of the file
#define CANDLES_5M  72    // Six hours of 5M candles (12 * 6)
#define CANDLES_15M 24    // Six hours of 15M candles (4 * 6)
#define CANDLES_1H  10     // Six hours of 1H candles
#define CANDLES_4H  10     // Two 4H candles
#define CANDLES_1D  10    // One day candle

// Add these new constants for pattern detection
#define PATTERN_LOOKBACK 100  // Lookback period for pattern detection
#define VOLUME_MA_PERIOD 20   // Period for volume moving average
#define PIVOT_POINTS_DAYS 3   // Number of days for pivot point calculation

// Add this with other input parameters
enum ENUM_RISK_LEVEL {
    RISK_LOW = 0,     // Low Risk Only
    RISK_MEDIUM = 1,  // Medium Risk & Lower
    RISK_HIGH = 2     // All Risk Levels
};

input ENUM_RISK_LEVEL InpRiskLevel = RISK_MEDIUM;  // Risk Level Filter

// Add with other input parameters
bool InpShowAbout = false;              // Show About Message on Start

// Add these constants at the top of the file
#define SCREENSHOT_WIDTH 1024   // Screenshot width in pixels
#define SCREENSHOT_HEIGHT 768   // Screenshot height in pixels
#define SCREENSHOT_PATH "\\Screenshots\\"  // Subfolder for screenshots

// Add this enum after the existing ENUM_RISK_LEVEL definition
enum ENUM_BOT_TYPE {
    BOT_AI_INDICATOR = 0,    // AI Indicator
    BOT_AI_TRADER = 1        // AI Trader
};

// Add this input parameter with other input parameters
input ENUM_BOT_TYPE InpBotType = BOT_AI_TRADER;    // Bot Type

// Add these constants for arrow properties
#define ARROW_OFFSET 3           // Offset from high/low price
#define ARROW_SIZE 5             // Size of the arrow
#define ARROW_COLOR_BUY clrLime  // Color for buy signals
#define ARROW_COLOR_SELL clrRed  // Color for sell signals
#define ARROW_COLOR_HOLD clrGray // Color for hold signals

// Add these object name prefixes
#define OBJ_PREFIX_SIGNAL "AI_Signal_"
#define OBJ_PREFIX_CONF "AI_Conf_"

//| Complex pattern detection structure                               |
//+------------------------------------------------------------------+
struct PatternInfo {
    string pattern_name;
    string timeframe;
    double formation_high;
    double formation_low;
    double target_price;
    string direction;    // "bullish" or "bearish"
    int confidence;      // 0-100
};

//+------------------------------------------------------------------+
//| Candlestick data structure                                        |
//+------------------------------------------------------------------+
struct CandleData {
    datetime time;
    double open;
    double high;
    double low;
    double close;
    double volume;
    bool bullish;
    double body_size;
    double upper_shadow;
    double lower_shadow;
    double body_ratio;
    string pattern;
};

//+------------------------------------------------------------------+
//| Market data structure                                             |
//+------------------------------------------------------------------+
struct MarketData {
    string market_session;
    string market_phase;
    bool news_pending;
    double avg_daily_range;
    double daily_high;
    double daily_low;
    
    // Volatility metrics (only one set)
    double daily_volatility;
    double weekly_volatility;
    double monthly_volatility;
    
    string trend;
    string trend_15m;
    string trend_1h;
    string trend_4h;
    string trend_1d;
    
    double adx;
    double di_plus;
    double di_minus;
    double current_price;
    double bollinger_upper;
    double bollinger_lower;
    double bollinger_width;
    bool at_fib_level;
    
    double r3, r2, r1;
    double pivot_point;
    double s1, s2, s3;
    
    string volume_trend;
    double buy_sell_ratio;
    double mfi;
    double volume_imbalance;
    
    double rsi;
    double stochastic_k;
    double stochastic_d;
    double macd;
    double macd_signal; 
    double williams;
    
    string candlestick_patterns;
    string technical_patterns;
    
    CandleData candles_15m[];
    CandleData candles_1h[];
    CandleData candles_4h[];
    CandleData candles_1d[];
    
    double rsi_history[];
    double macd_history[];
    double macd_signal_history[];
    double adx_history[];
    double di_plus_history[];
    double di_minus_history[];
    double stoch_k_history[];
    double stoch_d_history[];
    double bb_upper_history[];
    double bb_lower_history[];
    double volume_history[];
    double mfi_history[];
    double price_history[];
    double atr_history[];
    
    string supply_zones[];
    string demand_zones[];
    string key_levels[];
    
    double weekly_low;
    double weekly_high;
    double atr;
    
    // Add new fields for extended analysis
    double volume_ma;           // Volume moving average
    double prev_day_volume;     // Previous day's volume
    double week_open;           // Week opening price
    double month_open;          // Month opening price
    double prev_day_close;      // Previous day's closing price
    
    // Multiple timeframe RSI
    double rsi_15m;
    double rsi_1h;
    double rsi_4h;
    double rsi_1d;
    
    // Multiple timeframe MACD
    double macd_15m;
    double macd_signal_15m;
    double macd_1h;
    double macd_signal_1h;
    
    // Pivot points for multiple days
    struct PivotPoints {
        double pp;  // Pivot point
        double r1, r2, r3;  // Resistance levels
        double s1, s2, s3;  // Support levels
    } pivots[3];  // Last 3 days
    
    // Price action patterns
    string patterns_15m[];
    string patterns_1h[];
    string patterns_4h[];
    string patterns_1d[];
    
    // Market statistics
    double avg_true_range_15m;
    double avg_true_range_1h;
    double avg_true_range_4h;
    double avg_true_range_1d;
    
    string trend_5m;      // Add 5M trend
    double rsi_5m;        // Add 5M RSI
    double macd_5m;       // Add 5M MACD
    double macd_signal_5m; // Add 5M MACD signal
    CandleData candles_5m[];  // Add 5M candles array
    string patterns_5m[]; // Add 5M patterns array
    double avg_true_range_5m; // Add 5M ATR
};

// Add global MarketData instance
MarketData gData;

//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
int totalActiveTrades = 0;
datetime lastUpdateTime = 0;

// Replace the original variables
input int InpMaxActiveTrades = 5;          // Maximum Active Trades
input double InpLotSize = 0.1;              // Trading Lot Size
input int InpMinConfidence = 75;            // Minimum Confidence Level (0-100)
input int InpUpdateInterval = 5;            // AI Update Interval (minutes, min=5)
input string InpApiKey = "Contact beshoo@gmail.com for more info";    // API Key
string InpApiEndpoint = "https://chat.mustashar.vip/openai.php"; // API Endpoint URL
bool InpAllowAlgoTrading = true;      // Allow Algo Trading

// Add these input parameters
int InpPriceCollectionMins = 240;      // Price Collection Reset Period (minutes)
int InpPriceCollectionFreq = 1;       // Price Collection Frequency (minutes)
int InpMinPricesBeforeAnalysis = 0;  // Minimum prices before analysis

// Add this structure for price history
struct PricePoint {
    datetime time;
    double price;
    double high;    // Make sure these fields exist
    double low;     // Make sure these fields exist
    string movement;
};

// Add these global variables
PricePoint priceHistory[];
datetime lastPriceCollection = 0;
bool isCollectingPrices = false;
datetime collectionStartTime = 0;
int priceCollectionCount = 0;  // Add this to track number of prices collected

//+------------------------------------------------------------------+
//| Mode definitions                                                  |
//+------------------------------------------------------------------+
#define MODE_MAIN 0
#define MODE_PLUSDI 1
#define MODE_MINUSDI 2
#define MODE_SIGNAL 1
#define MODE_SMA 0

//+------------------------------------------------------------------+
//| Function declarations                                             |
//+------------------------------------------------------------------+
string AnalyzeTrend();
void AnalyzeSupplyDemandZones(MarketData &data);
string AnalyzeCandlePatterns();
string AnalyzeTechnicalPatterns();
double ATR(ENUM_TIMEFRAMES timeframe);
void FindPeaks(const double &array[], int &peaks[], int min_distance);
double CalculateHSTarget(const double &highs[], const double &lows[]);
double CalculateIHSTarget(const double &highs[], const double &lows[]);
double CalculateDoubleTopTarget(const double &highs[], const double &lows[]);
double CalculateTriangleTarget(const double &highs[], const double &lows[], string type);
void CalculateLinearRegression(const double &x[], const double &y[], double &slope, double &intercept);
void ArrayAppend(PatternInfo &array[], PatternInfo &element);
string ArrayToString(const string &array[]);
bool DetectInverseHeadAndShoulders(const double &highs[], const double &lows[], const double &closes[], ENUM_TIMEFRAMES timeframe);
bool DetectDoubleTop(const double &highs[], const double &lows[], const double &closes[]);
bool OpenBuyOrder(double lot, double sl, double tp);
bool OpenSellOrder(double lot, double sl, double tp);
CandleData AnalyzeCandlePattern(int shift, ENUM_TIMEFRAMES timeframe);
bool DetectDoubleBottom(const double &highs[], const double &lows[], const double &closes[]);
double CalculateDoubleBottomTarget(const double &highs[], const double &lows[]);
bool DetectPriceChannel(const double &highs[], const double &lows[], double &channelTop, double &channelBottom);
bool InitializeArray(double &array[], int size, string arrayName);
bool CopyIndicatorBuffer(int handle, int buffer_num, int start_pos, int count, 
double &buffer[], string indicatorName);
bool IsRiskLevelAllowed(const string risk_level);  // Add this line

// Add these helper functions at the top of the file after the existing #define statements

//+------------------------------------------------------------------+
//| Safe array access with bounds checking                             |
//+------------------------------------------------------------------+
double SafeArrayGet(const double &array[], int index, double defaultValue = 0.0) {
    if(index < 0 || index >= ArraySize(array)) {
        return defaultValue;
    }
    return array[index];
}

//+------------------------------------------------------------------+
//| Safe array resize with initialization                              |
//+------------------------------------------------------------------+
bool SafeArrayResize(double &array[], int newSize, string arrayName) {
    if(newSize <= 0) {
        Print("Invalid size requested for ", arrayName, ": ", newSize);
        return false;
    }
    
    if(!ArrayResize(array, newSize)) {
        Print("Failed to resize ", arrayName, " to size ", newSize);
        return false;
    }
    
    ArrayInitialize(array, 0.0);
    return true;
}

//+------------------------------------------------------------------+
//| Safe array resize for CandleData arrays                            |
//+------------------------------------------------------------------+
bool SafeArrayResizeCandleData(CandleData &array[], int newSize, string arrayName) {
    if(newSize <= 0) {
        Print("Invalid size requested for ", arrayName, ": ", newSize);
        return false;
    }
    
    if(!ArrayResize(array, newSize)) {
        Print("Failed to resize ", arrayName, " to size ", newSize);
        return false;
    }
    
    // Initialize CandleData elements with default values
    for(int i = 0; i < newSize; i++) {
        array[i].time = 0;
        array[i].open = 0.0;
        array[i].high = 0.0;
        array[i].low = 0.0;
        array[i].close = 0.0;
        array[i].volume = 0.0;
        array[i].bullish = false;
        array[i].body_size = 0.0;
        array[i].upper_shadow = 0.0;
        array[i].lower_shadow = 0.0;
        array[i].body_ratio = 0.0;
        array[i].pattern = "";
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize arrays in MarketData structure                          |
//+------------------------------------------------------------------+
bool InitializeMarketDataArrays(MarketData &data) {
    // Initialize all fixed-size arrays
    if(!SafeArrayResize(data.rsi_history, HISTORY_SIZE, "RSI History") ||
       !SafeArrayResize(data.macd_history, HISTORY_SIZE, "MACD History") ||
       !SafeArrayResize(data.macd_signal_history, HISTORY_SIZE, "MACD Signal History") ||
       !SafeArrayResize(data.adx_history, HISTORY_SIZE, "ADX History") ||
       !SafeArrayResize(data.di_plus_history, HISTORY_SIZE, "DI+ History") ||
       !SafeArrayResize(data.di_minus_history, HISTORY_SIZE, "DI- History") ||
       !SafeArrayResize(data.stoch_k_history, HISTORY_SIZE, "Stochastic K History") ||
       !SafeArrayResize(data.stoch_d_history, HISTORY_SIZE, "Stochastic D History") ||
       !SafeArrayResize(data.bb_upper_history, HISTORY_SIZE, "Bollinger Upper History") ||
       !SafeArrayResize(data.bb_lower_history, HISTORY_SIZE, "Bollinger Lower History") ||
       !SafeArrayResize(data.volume_history, HISTORY_SIZE, "Volume History") ||
       !SafeArrayResize(data.mfi_history, HISTORY_SIZE, "MFI History") ||
       !SafeArrayResize(data.price_history, HISTORY_SIZE, "Price History") ||
       !SafeArrayResize(data.atr_history, HISTORY_SIZE, "ATR History")) {
        return false;
    }
    
    // Initialize candlestick arrays with the new function
    if(!SafeArrayResizeCandleData(data.candles_15m, 24, "15M Candles") ||
       !SafeArrayResizeCandleData(data.candles_1h, 6, "1H Candles") ||
       !SafeArrayResizeCandleData(data.candles_4h, 2, "4H Candles") ||
       !SafeArrayResizeCandleData(data.candles_1d, 1, "1D Candles")) {
        return false;
    }
    
    // Initialize zone arrays
    ArrayResize(data.supply_zones, 0);
    ArrayResize(data.demand_zones, 0);
    ArrayResize(data.key_levels, 0);
    
    return true;
}

//+------------------------------------------------------------------+
//| Append element to dynamic array                                    |
//+------------------------------------------------------------------+
void ArrayAppend(PatternInfo &array[], PatternInfo &element) {
    int size = ArraySize(array);
    ArrayResize(array, size + 1);
    array[size] = element;
}




//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
    // Add this validation at the start
    if(InpUpdateInterval < 5) {
        string message = StringFormat("Invalid update interval: %d. Must be at least 5 minutes.", InpUpdateInterval);
        Alert(message);
        Print(message);
        return INIT_PARAMETERS_INCORRECT;
    }

    // Add this validation
    if(InpUpdateInterval > 1440) {  // 1440 minutes = 24 hours
        string message = StringFormat("Invalid update interval: %d. Must not exceed 1440 minutes (24 hours).", InpUpdateInterval);
        Alert(message);
        Print(message);
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Set timer to check every 5 minutes instead of every minute
    if(!EventSetTimer(300)) {  // 300 seconds = 5 minutes
        Print("Failed to set timer");
        return INIT_FAILED;
    }
    
    // Reset the last update time on initialization
    lastUpdateTime = 0;
    
    // Initialize trade count
    totalActiveTrades = CountActiveTrades();
    
    // Initialize all arrays in gData
    if(!InitializeMarketDataArrays(gData)) {
        Print("Failed to initialize market data arrays");
        return INIT_FAILED;
    }
    
    // Check if algo trading is allowed
    if(!InpAllowAlgoTrading) {
        Print("Algo trading is not allowed. Please enable it in MT5 settings.");
        return INIT_FAILED;
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
    
    // Clean up old screenshots
    CleanupOldScreenshots();
}

//+------------------------------------------------------------------+
//| Clean up screenshots older than 7 days                             |
//+------------------------------------------------------------------+
void CleanupOldScreenshots() {
    string terminal_data_path = TerminalInfoString(TERMINAL_DATA_PATH);
    string screenshot_folder = terminal_data_path + "\\MQL5\\Files" + SCREENSHOT_PATH;
    
    // Get current time
    datetime current_time = TimeCurrent();
    string search_pattern = screenshot_folder + "*.png";
    string file_name;  // Variable to store found file name
    
    long handle = FileFindFirst(search_pattern, file_name);  // Correct syntax
    
    if(handle != INVALID_HANDLE) {
        do {
            string full_path = screenshot_folder + file_name;
            datetime file_time = (datetime)FileGetInteger(full_path, FILE_CREATE_DATE);
            
            // Delete files older than 7 days
            if(current_time - file_time > 7 * 24 * 60 * 60) {  
                if(!FileDelete(full_path)) {
                    Print("Failed to delete old screenshot: ", file_name);
                }
            }
        } while(FileFindNext(handle, file_name));  // Use file_name variable
        
        FileFindClose(handle);
    }
}

string GetCurrentTimeframeStr() {
    ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)ChartPeriod(0);
    
    switch(timeframe) {
        case PERIOD_M1:  return "PERIOD_M1";
        case PERIOD_M2:  return "PERIOD_M2";
        case PERIOD_M3:  return "PERIOD_M3";
        case PERIOD_M4:  return "PERIOD_M4";
        case PERIOD_M5:  return "PERIOD_M5";
        case PERIOD_M6:  return "PERIOD_M6";
        case PERIOD_M10: return "PERIOD_M10";
        case PERIOD_M12: return "PERIOD_M12";
        case PERIOD_M15: return "PERIOD_M15";
        case PERIOD_M20: return "PERIOD_M20";
        case PERIOD_M30: return "PERIOD_M30";
        case PERIOD_H1:  return "PERIOD_H1";
        case PERIOD_H2:  return "PERIOD_H2";
        case PERIOD_H3:  return "PERIOD_H3";
        case PERIOD_H4:  return "PERIOD_H4";
        case PERIOD_H6:  return "PERIOD_H6";
        case PERIOD_H8:  return "PERIOD_H8";
        case PERIOD_H12: return "PERIOD_H12";
        case PERIOD_D1:  return "PERIOD_D1";
        case PERIOD_W1:  return "PERIOD_W1";
        case PERIOD_MN1: return "PERIOD_MN1";
        default:         return "PERIOD_CURRENT";
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Call the function to monitor and adjust trades on each tick
   // MonitorAndAdjustTrades();

    // Monitor existing trades
    MonitorActiveTrades();

    // Exit early if not time to update
    if(!IsTimeToUpdate())
        return;

    // Ensure we haven't exceeded the max active trades
    if(CountActiveTrades() >= InpMaxActiveTrades)
    {
        Print("Maximum trades (", InpMaxActiveTrades, ") reached. Skipping analysis.");
        return;
    }

    // Check local signals here — might place trades
    //CheckLocalTradeSignals();


    // Proceed only if there's still capacity to add trades

    // Collect price data
    CollectPriceData();

    // Gather market data
    MarketData data;
    if(!GatherMarketData(data))
    {
        Print("Failed to gather market data");
        return;
    }

    // Prepare analysis
    string analysis = PrepareAnalysisRequest(data);
    if(analysis == "")
    {
        Print("Failed to prepare analysis request");
        return;
    }

    // Send to AI and process the response
    string response = SendToGPT(analysis);
    if(response != "")
    {
        ProcessTradeSignal(response);
    }
    else
    {
        Print("No valid response from AI analysis");
    }
}


//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer() {
    // Only check every 5 minutes instead of every minute
    static datetime lastCheck = 0;
    datetime currentTime = TimeCurrent();
    
    if(currentTime - lastCheck < 300) { // 300 seconds = 5 minutes
        return;
    }
    
    lastCheck = currentTime;
    
    // Calculate time until next update
    int minutesUntilUpdate = GetTimeUntilNextUpdate();
    
    if(minutesUntilUpdate <= 5) {  // Only print when close to next update
        Print("Timer check - Next update in ", minutesUntilUpdate, " minutes");
    }
}

//+------------------------------------------------------------------+
//| Helper function to get minutes until next update                   |
//+------------------------------------------------------------------+
int GetTimeUntilNextUpdate() {
    if(lastUpdateTime == 0) return 0;
    
    datetime currentTime = TimeCurrent();
    int minutesElapsed = (int)((currentTime - lastUpdateTime) / 60);
    return MathMax(0, InpUpdateInterval - minutesElapsed);
}

//+------------------------------------------------------------------+
//| Check if it's time to update analysis                             |
//+------------------------------------------------------------------+
bool IsTimeToUpdate() {
    static datetime lastDebugTime = 0;
    datetime currentTime = TimeCurrent();
    
    // First run
    if(lastUpdateTime == 0) {
        Print("First update - Initializing lastUpdateTime");
        lastUpdateTime = currentTime;
        return true;
    }
    
    // Calculate time elapsed since last update in minutes
    int minutesElapsed = (int)((currentTime - lastUpdateTime) / 60);
    
    // Add more detailed debug information
    if(currentTime - lastDebugTime >= 900) {  // 900 seconds = 15 minutes
        Print("=== Detailed Update Status ===");
        Print("Current Time: ", TimeToString(currentTime));
        Print("Last Update Time: ", TimeToString(lastUpdateTime));
        Print("Minutes Elapsed: ", minutesElapsed);
        Print("Update Interval Setting: ", InpUpdateInterval);
        Print("Time Until Next Update: ", InpUpdateInterval - minutesElapsed, " minutes");
        Print("=============================");
        lastDebugTime = currentTime;
    }
    
    // Check if enough time has passed
    if(minutesElapsed >= InpUpdateInterval) {
        Print("=== Executing scheduled update ===");
        Print("Minutes elapsed since last update: ", minutesElapsed);
        Print("Update interval setting: ", InpUpdateInterval);
        lastUpdateTime = currentTime;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Collect and analyze price movements                               |
//+------------------------------------------------------------------+
void CollectPriceData() {
    datetime currentTime = TimeCurrent();
    
}

//+------------------------------------------------------------------+
//| Gather all relevant market data                                   |
//+------------------------------------------------------------------+
bool GatherMarketData(MarketData &data) {  // Changed return type to bool
    // Initialize basic data
    data.current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    data.market_session = DetermineMarketSession();
    data.news_pending = false;  // Set this based on your news checking logic
    
    Print("GatherMarketData - Initial values:");
    Print("Current Price: ", data.current_price);
    Print("Market Session: ", data.market_session);
    Print("News Pending: ", data.news_pending ? "Yes" : "No");
    
    // Initialize arrays first
    if(!InitializeMarketDataArrays(data)) {
        Print("Failed to initialize arrays in GatherMarketData");
        return false;  // Return false on failure
    }
    
    // Set market session and phase
    data.market_session = DetermineMarketSession();
    data.market_phase = DetermineMarketPhase();
    
    // Gather and print debug info
    data.current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    Print("Debug - Current Price: ", data.current_price);
    
    data.news_pending = false;  // or your news checking logic
    Print("Debug - News Pending: ", data.news_pending ? "Yes" : "No");
    
    // Get daily high/low
    data.daily_high = iHigh(_Symbol, PERIOD_D1, 0);
    data.daily_low = iLow(_Symbol, PERIOD_D1, 0);
    
    // Analyze trends for different timeframes
    data.trend = AnalyzeTrend();
    data.trend_5m = AnalyzeTrendForTimeframe(PERIOD_M5);  // Keep this one
    data.trend_15m = AnalyzeTrendForTimeframe(PERIOD_M15);
    data.trend_1h = AnalyzeTrendForTimeframe(PERIOD_H1);
    data.trend_4h = AnalyzeTrendForTimeframe(PERIOD_H4);
    data.trend_1d = AnalyzeTrendForTimeframe(PERIOD_D1);
    
    // Calculate technical indicators
    int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    double temp[];
    ArraySetAsSeries(temp, true);
    
    if(CopyIndicatorBuffer(rsi_handle, 0, 0, 1, temp, "RSI")) {
        data.rsi = SafeArrayGet(temp, 0);
    }
    IndicatorRelease(rsi_handle);
    
    int adx_handle = iADX(_Symbol, PERIOD_CURRENT, 14);
    if(CopyIndicatorBuffer(adx_handle, MODE_MAIN, 0, 1, temp, "ADX")) {
        data.adx = SafeArrayGet(temp, 0);
    }
    if(CopyIndicatorBuffer(adx_handle, MODE_PLUSDI, 0, 1, temp, "DI+")) {
        data.di_plus = SafeArrayGet(temp, 0);
    }
    if(CopyIndicatorBuffer(adx_handle, MODE_MINUSDI, 0, 1, temp, "DI-")) {
        data.di_minus = SafeArrayGet(temp, 0);
    }
    IndicatorRelease(adx_handle);
    
    int stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, 5, 3, 3, MODE_SMA, STO_PRICE_CLOSE);
    double k_buffer[], d_buffer[];
    ArraySetAsSeries(k_buffer, true);
    ArraySetAsSeries(d_buffer, true);
    
    if(CopyIndicatorBuffer(stoch_handle, MAIN_LINE, 0, 1, k_buffer, "Stochastic K")) {
        data.stochastic_k = SafeArrayGet(k_buffer, 0);
    }
    if(CopyIndicatorBuffer(stoch_handle, SIGNAL_LINE, 0, 1, d_buffer, "Stochastic D")) {
        data.stochastic_d = SafeArrayGet(d_buffer, 0);
    }
    IndicatorRelease(stoch_handle);
    
    // Analyze supply and demand zones
    AnalyzeSupplyDemandZones(data);
    
    // Analyze candlestick patterns
    data.candlestick_patterns = AnalyzeCandlePatterns();
    
    // Analyze technical patterns
    data.technical_patterns = AnalyzeTechnicalPatterns();
    
    // Gather candlestick data for multiple timeframes
    // 15M candles (last 12 hours = 48 candles)
    if(!SafeArrayResizeCandleData(data.candles_15m, 24, "15M Candles") ||
       !SafeArrayResizeCandleData(data.candles_1h, 6, "1H Candles") ||
       !SafeArrayResizeCandleData(data.candles_4h, 2, "4H Candles") ||
       !SafeArrayResizeCandleData(data.candles_1d, 1, "1D Candles")) {
        Print("Failed to resize candle arrays");
        return false;
    }
    for(int i = 0; i < 24; i++) {
        CandleData candle = AnalyzeCandlePattern(i, PERIOD_M15);
        data.candles_15m[i] = candle;
    }
    
    // 1H candles (last 12 hours = 12 candles)
    for(int i = 0; i < 6; i++) {
        CandleData candle = AnalyzeCandlePattern(i, PERIOD_H1);
        data.candles_1h[i] = candle;
    }
    
    // 4H candles (last 12 hours = 3 candles)
    for(int i = 0; i < 2; i++) {
        CandleData candle = AnalyzeCandlePattern(i, PERIOD_H4);
        data.candles_4h[i] = candle;
    }
    
    // Daily candle (current and previous)
    for(int i = 0; i < 1; i++) {
        CandleData candle = AnalyzeCandlePattern(i, PERIOD_D1);
        data.candles_1d[i] = candle;
    }
    
    // Add complex pattern detection for each timeframe
    string patterns15M = DetectComplexPatterns(PERIOD_M15, 24);
    string patterns1H = DetectComplexPatterns(PERIOD_H1, 6);
    string patterns4H = DetectComplexPatterns(PERIOD_H4, 2);
    string patternsD1 = DetectComplexPatterns(PERIOD_D1, 1);
    
    // Add pattern information to the technical_patterns field
    data.technical_patterns = StringFormat(
        "15M Patterns:\n%s\n"
        "1H Patterns:\n%s\n"
        "4H Patterns:\n%s\n"
        "D1 Patterns:\n%s",
        patterns15M,
        patterns1H,
        patterns4H,
        patternsD1
    );
    
    // Gather historical indicator values
    for(int i = 0; i < HISTORY_SIZE; i++) {
        double temp[];
        ArraySetAsSeries(temp, true);
        
        // RSI
        int rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
        if(rsi_handle != INVALID_HANDLE) {
            if(CopyBuffer(rsi_handle, 0, i, 1, temp) > 0) {
                data.rsi_history[i] = SafeArrayGet(temp, 0);
            }
            IndicatorRelease(rsi_handle);
        }
        
        // MACD
        int macd_handle = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
        if(macd_handle != INVALID_HANDLE) {
            double macd_main[], macd_signal[];
            ArraySetAsSeries(macd_main, true);
            ArraySetAsSeries(macd_signal, true);
            
            if(CopyBuffer(macd_handle, MAIN_LINE, i, 1, macd_main) > 0 &&
               CopyBuffer(macd_handle, SIGNAL_LINE, i, 1, macd_signal) > 0) {
                data.macd_history[i] = SafeArrayGet(macd_main, 0);
                data.macd_signal_history[i] = SafeArrayGet(macd_signal, 0);
            }
            IndicatorRelease(macd_handle);
        }
        
        // ADX
        int adx_handle = iADX(_Symbol, PERIOD_CURRENT, 14);
        if(adx_handle != INVALID_HANDLE) {
            if(CopyBuffer(adx_handle, MODE_MAIN, i, 1, temp) > 0) {
                data.adx_history[i] = SafeArrayGet(temp, 0);
            }
            if(CopyBuffer(adx_handle, MODE_PLUSDI, i, 1, temp) > 0) {
                data.di_plus_history[i] = SafeArrayGet(temp, 0);
            }
            if(CopyBuffer(adx_handle, MODE_MINUSDI, i, 1, temp) > 0) {
                data.di_minus_history[i] = SafeArrayGet(temp, 0);
            }
            IndicatorRelease(adx_handle);
        }
        
        // Stochastic
        int stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, 5, 3, 3, MODE_SMA, STO_PRICE_CLOSE);
        if(stoch_handle != INVALID_HANDLE) {
            if(CopyBuffer(stoch_handle, MAIN_LINE, i, 1, temp) > 0) {
                data.stoch_k_history[i] = SafeArrayGet(temp, 0);
            }
            if(CopyBuffer(stoch_handle, SIGNAL_LINE, i, 1, temp) > 0) {
                data.stoch_d_history[i] = SafeArrayGet(temp, 0);
            }
            IndicatorRelease(stoch_handle);
        }
        
        // Bollinger Bands
        int bb_handle = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2, PRICE_CLOSE);
        if(bb_handle != INVALID_HANDLE) {
            double bb_upper[], bb_lower[];
            ArraySetAsSeries(bb_upper, true);
            ArraySetAsSeries(bb_lower, true);
            
            if(CopyBuffer(bb_handle, 1, i, 1, bb_upper) > 0) {
                data.bb_upper_history[i] = SafeArrayGet(bb_upper, 0);
            }
            if(CopyBuffer(bb_handle, 2, i, 1, bb_lower) > 0) {
                data.bb_lower_history[i] = SafeArrayGet(bb_lower, 0);
            }
            IndicatorRelease(bb_handle);
        }
        
        // Volume
        long volume[];
        ArraySetAsSeries(volume, true);
        if(CopyRealVolume(_Symbol, PERIOD_CURRENT, i, 1, volume) > 0) {
            data.volume_history[i] = (double)volume[0];
        }
        
        // MFI
        int mfi_handle = iMFI(_Symbol, PERIOD_CURRENT, 14, VOLUME_TICK);
        if(mfi_handle != INVALID_HANDLE) {
            if(CopyBuffer(mfi_handle, 0, i, 1, temp) > 0) {
                data.mfi_history[i] = SafeArrayGet(temp, 0);
            }
            IndicatorRelease(mfi_handle);
        }
        
        // Price
        double close[];
        ArraySetAsSeries(close, true);
        if(CopyClose(_Symbol, PERIOD_CURRENT, i, 1, close) > 0) {
            data.price_history[i] = SafeArrayGet(close, 0);
        }
        
        // ATR
        int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
        if(atr_handle != INVALID_HANDLE) {
            if(CopyBuffer(atr_handle, 0, i, 1, temp) > 0) {
                data.atr_history[i] = SafeArrayGet(temp, 0);
            }
            IndicatorRelease(atr_handle);
        }
    }
    
    // Gather historical candlestick data
    GatherHistoricalCandleData(data.candles_5m, PERIOD_M5, CANDLES_5M);   // Add this line
    GatherHistoricalCandleData(data.candles_15m, PERIOD_M15, CANDLES_15M);
    GatherHistoricalCandleData(data.candles_1h, PERIOD_H1, CANDLES_1H);
    GatherHistoricalCandleData(data.candles_4h, PERIOD_H4, CANDLES_4H);
    GatherHistoricalCandleData(data.candles_1d, PERIOD_D1, CANDLES_1D);
    
    // Calculate multiple timeframe RSI
    data.rsi_5m = CalculateRSI(PERIOD_M5);   // Add this line
    data.rsi_15m = CalculateRSI(PERIOD_M15);
    data.rsi_1h = CalculateRSI(PERIOD_H1);
    data.rsi_4h = CalculateRSI(PERIOD_H4);
    data.rsi_1d = CalculateRSI(PERIOD_D1);
    
    // Calculate multiple timeframe MACD
    CalculateMACD(PERIOD_M5, data.macd_5m, data.macd_signal_5m);   // Add this line
    CalculateMACD(PERIOD_M15, data.macd_15m, data.macd_signal_15m);
    CalculateMACD(PERIOD_H1, data.macd_1h, data.macd_signal_1h);
    
    // Calculate pivot points for last 3 days
    for(int i = 0; i < 3; i++) {
        CalculatePivotPoints(i, data.pivots[i]);
    }
    
    // Calculate volatility metrics
    UpdateVolatilityMetrics(data);
    
    // Get opening prices
    data.week_open = iOpen(_Symbol, PERIOD_W1, 0);
    data.month_open = iOpen(_Symbol, PERIOD_MN1, 0);
    data.prev_day_close = iClose(_Symbol, PERIOD_D1, 1);
    
    // Calculate volume metrics
    CalculateVolumeMetrics(data);
    
    // Calculate ATR for multiple timeframes
    data.avg_true_range_5m = iATR(_Symbol, PERIOD_M5, 14);    // Add this line
    data.avg_true_range_15m = iATR(_Symbol, PERIOD_M15, 14);
    data.avg_true_range_1h = iATR(_Symbol, PERIOD_H1, 14);
    data.avg_true_range_4h = iATR(_Symbol, PERIOD_H4, 14);
    data.avg_true_range_1d = iATR(_Symbol, PERIOD_D1, 14);
    
    // Detect patterns for each timeframe
    DetectPatternsForTimeframe(PERIOD_M5, data.patterns_5m);   // Add this line
    DetectPatternsForTimeframe(PERIOD_M15, data.patterns_15m);
    DetectPatternsForTimeframe(PERIOD_H1, data.patterns_1h);
    DetectPatternsForTimeframe(PERIOD_H4, data.patterns_4h);
    DetectPatternsForTimeframe(PERIOD_D1, data.patterns_1d);
    
    return true;  // Return true if everything succeeded
}

//+------------------------------------------------------------------+
//| Prepare analysis request for GPT                                  |
//+------------------------------------------------------------------+
string PrepareAnalysisRequest(MarketData &data) {
    // Keep existing validation code
    double lotSize = InpLotSize;
    if(lotSize <= 0) {
        Print("Warning: Invalid lot size, using default 0.1");
        lotSize = 0.1;
    }
    
    // Start with your original trading prompt
    string request = "\n=== HISTORICAL MARKET DATA ANALYSIS ===\n\n";
    
    // Add historical data for each timeframe
    request += "=== 5M Timeframe Historical Data ===\n";
    request += PrepareTimeframeHistory(PERIOD_M5, data);
    
    request += "\n=== 15M Timeframe Historical Data ===\n";
    request += PrepareTimeframeHistory(PERIOD_M15, data);
    
    request += "\n=== 1H Timeframe Historical Data ===\n";
    request += PrepareTimeframeHistory(PERIOD_H1, data);
    
    request += "\n=== 4H Timeframe Historical Data ===\n";
    request += PrepareTimeframeHistory(PERIOD_H4, data);
    
    request += "\n=== 1D Timeframe Historical Data ===\n";
    request += PrepareTimeframeHistory(PERIOD_D1, data);
    
    // Add market conditions section
    string marketConditions = StringFormat(
        "\n=== TRADING PARAMETERS ===\n"
        "Maximum Lot Size: %.2f\n\n"
        "=== CURRENT MARKET CONDITIONS ===\n"
        "Symbol: %s\n"
        "Current Price: %.5f\n"
        "Market Session: %s\n"
        "News Events Pending: %s\n\n",
        lotSize,
        _Symbol,
        data.current_price,
        data.market_session,
        data.news_pending ? "Yes" : "No"
    );
    
    request += marketConditions;
    
    // Add price movement analysis
    request += "\n=== PRICE MOVEMENT ANALYSIS ===\n";
    request += "Recent Price Movements:\n";
    
    int size = ArraySize(priceHistory);
    for(int i = 0; i < size; i++) {
        request += StringFormat(
            "Time: %s | Price: %.5f | Movement: %s\n",
            TimeToString(priceHistory[i].time),
            priceHistory[i].price,
            priceHistory[i].movement
        );
    }
    
    
    
      // Fifth part - Patterns and Volatility
    request += StringFormat(
        "=== PATTERN RECOGNITION ===\n"
        "Candlestick Patterns: %s\n"
        "Technical Patterns: %s\n\n"
        
        "=== VOLATILITY METRICS ===\n"
        "Daily Volatility: %.2f%%\n"
        "Weekly Volatility: %.2f%%\n"
        "Monthly Volatility: %.2f%%\n"
        "ATR (15M/1H/4H/1D): %.5f/%.5f/%.5f/%.5f\n\n"
        
        "=== ADDITIONAL METRICS ===\n"
        "Week Open: %.5f\n"
        "Month Open: %.5f\n"
        "Previous Day Close: %.5f\n\n",
        
        data.candlestick_patterns,
        data.technical_patterns,
        
        data.daily_volatility,
        data.weekly_volatility,
        data.monthly_volatility,
        data.avg_true_range_15m,
        data.avg_true_range_1h,
        data.avg_true_range_4h,
        data.avg_true_range_1d,
        
        data.week_open,
        data.month_open,
        data.prev_day_close
    );

    
    return request;
}

// Add this helper function to prepare historical data for each timeframe
string PrepareTimeframeHistory(ENUM_TIMEFRAMES timeframe, MarketData &data) {
    string history = "";
    int bars_to_include = 20; // Number of historical bars to include
    
    // Initialize arrays
    double rsi[], macd[], macd_signal[], adx[], di_plus[], di_minus[];
    double stoch_k[], stoch_d[], bb_upper[], bb_lower[], volume[], mfi[], atr[];
    double open[], high[], low[], close[];
    double ma20[], ma50[], ma200[];
    long volume_raw[];
    
    // Set arrays as series
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(ma20, true);
    ArraySetAsSeries(ma50, true);
    ArraySetAsSeries(ma200, true);
    ArraySetAsSeries(volume_raw, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(macd, true);
    ArraySetAsSeries(macd_signal, true);
    ArraySetAsSeries(adx, true);
    ArraySetAsSeries(di_plus, true);
    ArraySetAsSeries(di_minus, true);
    ArraySetAsSeries(stoch_k, true);
    ArraySetAsSeries(stoch_d, true);
    ArraySetAsSeries(bb_upper, true);
    ArraySetAsSeries(bb_lower, true);
    ArraySetAsSeries(mfi, true);
    ArraySetAsSeries(atr, true);
    
    // Copy price and volume data
    CopyOpen(_Symbol, timeframe, 0, bars_to_include, open);
    CopyHigh(_Symbol, timeframe, 0, bars_to_include, high);
    CopyLow(_Symbol, timeframe, 0, bars_to_include, low);
    CopyClose(_Symbol, timeframe, 0, bars_to_include, close);
    CopyTickVolume(_Symbol, timeframe, 0, bars_to_include, volume_raw);
    
    // Get indicator handles
    int rsi_handle = iRSI(_Symbol, timeframe, 14, PRICE_CLOSE);
    int macd_handle = iMACD(_Symbol, timeframe, 12, 26, 9, PRICE_CLOSE);
    int stoch_handle = iStochastic(_Symbol, timeframe, 5, 3, 3, MODE_SMA, STO_PRICE_CLOSE);
    int adx_handle = iADX(_Symbol, timeframe, 14);
    int bb_handle = iBands(_Symbol, timeframe, 20, 0, 2, PRICE_CLOSE);
    int mfi_handle = iMFI(_Symbol, timeframe, 14, VOLUME_TICK);
    int atr_handle = iATR(_Symbol, timeframe, 14);
    int ma20_handle = iMA(_Symbol, timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);
    int ma50_handle = iMA(_Symbol, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
    int ma200_handle = iMA(_Symbol, timeframe, 200, 0, MODE_SMA, PRICE_CLOSE);
    
    // Copy indicator data
    CopyBuffer(rsi_handle, 0, 0, bars_to_include, rsi);
    CopyBuffer(macd_handle, MAIN_LINE, 0, bars_to_include, macd);
    CopyBuffer(macd_handle, SIGNAL_LINE, 0, bars_to_include, macd_signal);
    CopyBuffer(stoch_handle, MAIN_LINE, 0, bars_to_include, stoch_k);
    CopyBuffer(stoch_handle, SIGNAL_LINE, 0, bars_to_include, stoch_d);
    CopyBuffer(adx_handle, MODE_MAIN, 0, bars_to_include, adx);
    CopyBuffer(adx_handle, MODE_PLUSDI, 0, bars_to_include, di_plus);
    CopyBuffer(adx_handle, MODE_MINUSDI, 0, bars_to_include, di_minus);
    CopyBuffer(bb_handle, 1, 0, bars_to_include, bb_upper);
    CopyBuffer(bb_handle, 2, 0, bars_to_include, bb_lower);
    CopyBuffer(mfi_handle, 0, 0, bars_to_include, mfi);
    CopyBuffer(atr_handle, 0, 0, bars_to_include, atr);
    CopyBuffer(ma20_handle, 0, 0, bars_to_include, ma20);
    CopyBuffer(ma50_handle, 0, 0, bars_to_include, ma50);
    CopyBuffer(ma200_handle, 0, 0, bars_to_include, ma200);
    
    // Format the historical data
    history += "Historical Data for Last " + IntegerToString(bars_to_include) + " Bars:\n";
    for(int i = 0; i < bars_to_include; i++) {
        // Calculate candle characteristics
        double body_size = MathAbs(close[i] - open[i]);
        double upper_shadow = high[i] - MathMax(open[i], close[i]);
        double lower_shadow = MathMin(open[i], close[i]) - low[i];
        double total_range = high[i] - low[i];
        bool is_bullish = close[i] > open[i];
        
        // Determine candle type
        string candle_type = "";
        if(body_size < total_range * 0.1) {
            if(upper_shadow > lower_shadow * 3)
                candle_type = "Long-Legged Doji (Top)";
            else if(lower_shadow > upper_shadow * 3)
                candle_type = "Long-Legged Doji (Bottom)";
            else
                candle_type = "Doji";
        }
        else if(lower_shadow > body_size * 2 && upper_shadow < body_size * 0.5) {
            candle_type = is_bullish ? "Hammer" : "Hanging Man";
        }
        else if(upper_shadow > body_size * 2 && lower_shadow < body_size * 0.5) {
            candle_type = is_bullish ? "Inverted Hammer" : "Shooting Star";
        }
        else if(body_size > total_range * 0.8) {
            candle_type = is_bullish ? "Bullish Marubozu" : "Bearish Marubozu";
        }
        else {
            candle_type = is_bullish ? "Bullish Candle" : "Bearish Candle";
        }

        // Convert MACD values to pips
        double macd_pips = NormalizeDouble(macd[i] * 10000, 2);
        double signal_pips = NormalizeDouble(macd_signal[i] * 10000, 2);
        
        history += StringFormat(
            "Time: %s | %s | O: %.5f H: %.5f L: %.5f C: %.5f | %s | Body: %.1f%% | Shadows U:%.1f%% L:%.1f%% | Vol: %.2f | "
            "EMA(20,50)=(%.5f,%.5f) | RSI=%.2f, MACD=(%.2f,%.2f), ADX=(%.2f,%.2f,%.2f), "
            "Stoch=(%.2f,%.2f), BB=(%.5f,%.5f), MFI=%.2f, ATR=%.5f\n",
            TimeToString(iTime(_Symbol, timeframe, i)),
            is_bullish ? "BULL" : "BEAR",
            open[i],
            high[i],
            low[i],
            close[i],
            candle_type,
            (body_size/total_range)*100,
            (upper_shadow/total_range)*100,
            (lower_shadow/total_range)*100,
            (double)volume_raw[i],
            ma20[i],
            ma50[i],
            ma200[i],
            rsi[i],
            macd_pips, signal_pips,  // Using pips values
            adx[i],
            di_plus[i],
            di_minus[i],
            stoch_k[i],
            stoch_d[i],
            bb_upper[i],
            bb_lower[i],
            mfi[i],
            atr[i]
        );
    }
    
    /*
    // Add current values
    history += "\nCurrent Values:\n";
    history += StringFormat("Moving Averages: MA20=%.5f, MA50=%.5f, MA200=%.5f\n", ma20[0], ma50[0], ma200[0]);
    history += StringFormat("RSI: %.2f\n", rsi[0]);
    
    // Convert MACD values to pips for current values display
    double current_macd_pips = NormalizeDouble(macd[0] * 10000, 2);
    double current_signal_pips = NormalizeDouble(macd_signal[0] * 10000, 2);
    history += StringFormat("MACD: %.2f (Signal: %.2f)\n", current_macd_pips, current_signal_pips);
    
    history += StringFormat("ADX: %.2f (DI+: %.2f, DI-: %.2f)\n", adx[0], di_plus[0], di_minus[0]);
    history += StringFormat("Stochastic: K=%.2f, D=%.2f\n", stoch_k[0], stoch_d[0]);
    history += StringFormat("Bollinger Bands: Upper=%.5f, Lower=%.5f\n", bb_upper[0], bb_lower[0]);
    history += StringFormat("MFI: %.2f\n", mfi[0]);
    history += StringFormat("ATR: %.5f\n", atr[0]);
    */
    // Release all handles
    IndicatorRelease(rsi_handle);
    IndicatorRelease(macd_handle);
    IndicatorRelease(stoch_handle);
    IndicatorRelease(adx_handle);
    IndicatorRelease(bb_handle);
    IndicatorRelease(mfi_handle);
    IndicatorRelease(atr_handle);
    IndicatorRelease(ma20_handle);
    IndicatorRelease(ma50_handle);
    IndicatorRelease(ma200_handle);
    
    // Store current values in the MarketData structure
    data.rsi = rsi[0];
    data.macd = macd[0] * 10000;  // Convert to pips
    data.macd_signal = macd_signal[0] * 10000;  // Convert to pips
    data.adx = adx[0];
    data.di_plus = di_plus[0];
    data.di_minus = di_minus[0];
    // ... store other indicators in data structure as needed
    
    return history;
}

//+------------------------------------------------------------------+
//| Send analysis to GPT and parse response                           |
//+------------------------------------------------------------------+
string SendToGPT(string analysis) {
    // Take screenshot before sending request
    string screenshot_path = ""; //TakeChartScreenshot();
    if(screenshot_path == "") {
        Print("Warning: Failed to take chart screenshot");
    } else {
        Print("Chart screenshot saved to: ", screenshot_path);
    }
    
    // Create custom headers with account information
    string headers = StringFormat(
        "Content-Type: application/json\r\n"
        "Authorization: Bearer %s\r\n"
        "X-Account-Login: %lld\r\n"
        "X-Account-Name: %s\r\n"
        "X-Account-Server: %s\r\n"
        "X-Account-Company: %s\r\n"
        "X-Account-Currency: %s\r\n"
        "X-Account-Balance: %.2f\r\n"
        "X-Account-Equity: %.2f\r\n"
        "X-Screenshot-Path: %s\r\n",  // Add screenshot path to headers
        InpApiKey,
        AccountInfoInteger(ACCOUNT_LOGIN),
        AccountInfoString(ACCOUNT_NAME),
        AccountInfoString(ACCOUNT_SERVER),
        AccountInfoString(ACCOUNT_COMPANY),
        AccountInfoString(ACCOUNT_CURRENCY),
        AccountInfoDouble(ACCOUNT_BALANCE),
        AccountInfoDouble(ACCOUNT_EQUITY),
        screenshot_path
    );

    char post[], result[];
    string response_headers;
    
    // Escape special characters in the analysis string
    string escaped_analysis = analysis;
    StringReplace(escaped_analysis, "\"", "\\\"");
    StringReplace(escaped_analysis, "\n", "\\n");
    StringReplace(escaped_analysis, "\r", "\\r");
    
	string system_request = 
  "You are an advanced AI Forex indicator analyst with predictive capabilities. Analyze the market using support and resistance levels. "
 " and make your decision base on technical indicators and pattern recognition to identify optimal trading opportunities.\n\n"
 "Analyze the provided Japanese candlestick chart using the Inner Circle Trading (ICT) methodology is plus. we \n"
 "Your answer will used and indicator  on the chart we are using 30M time frame to show the mark on the chart"

/*
"=== EMA & BOLLINGER BANDS CROSSOVER STRATEGY ===\n\n"

"1. ENTRY CONDITIONS\n"
"LONG (BUY) ENTRY:\n"

"IMPORTANT: It is crucial for the EMA to **start crossing** at this moment on last 3 candelas 1 hour time frame , **not after the crossover has already happened**, like an hour earlier.\n"
" - The EMA(20) should cross above the EMA(50) at the very moment the uptrend begins (EMA slope changes from negative to positive). This **start of the crossover** should be observed within the last three 1-hour candles."
 "- Current closing price must be above the Upper Bollinger Band.\n"
"- IMPORTANT: Wait for candle close to confirm the setup.\n\n"
"- Timeframe: 1-hour\n\n"

"SHORT (SELL) ENTRY:\n"
"IMPORTANT: It is crucial for the EMA to **start crossing** at this moment on last 3 candelas 1 hour time frame, **not after the crossover has already happened**, like an hour earlier.\n"
" - The EMA(20) should cross below the EMA(50) at the very moment the downtrend begins (EMA slope changes from positive to negative). This **start of the crossover** should be observed within the last three 1-hour candles."

"- Current closing price must be below the Lower Bollinger Band.\n"
"- IMPORTANT: Wait for candle close to confirm the setup.\n\n"
"- Timeframe: 1-hour\n\n"
*/
/*
"### Risk Managment ####\n"

"## Stop Loss and Take Profet:\n"
"- A stop loss below the recent swing low (25 pips) and a take profit at a 1:2 risk-reward ratio (50 pips) \n"

"## Take Profit:\n"
"- Minimum 1:2 risk-reward ratio\n"

"## CONFIRMATION FILTERS\n"
//"- DO NOT trade if the market Equity is low , other wise HOLD the trade\n"
//"- Trade ONLY  in the active time of the session, do not open any trade if the session is in a down mode. other wise HOLD the trade\n"
//"- Avoid trading during major news events\n"
"- Check higher timeframe trend direction\n"
"- Monitor volume for confirmation\n"
"- Check for nearby support/resistance levels\n\n"

"## RISK MANAGEMENT\n"
"- Maximum risk per trade: 1%\n"
"- No trading during high-impact news\n"
"- Use proper position sizing\n"
"- Wait for candle close for confirmation\n\n"

"## BEST TRADING CONDITIONS\n"
"- Trade during main market sessions\n"
"- Monitor volatility using ATR\n\n"

"## IMPORTANT NOTES\n"
"- Support your decision by using support and resistance on the chart!"
"- Always wait for candle close\n"
"- Confirm EMA direction change\n"
"- Check BB expansion/contraction\n"
"- Monitor market volatility\n"
//"- Support your decision by checking crosover of EMA 20,50 , please note It is crucial for the EMA to **start crossing** at this moment on last 3 candelas 1 hour time frame , **not after the crossover has already happened**"
   
    "Important: 2 or more conditions must be met to complete the trade, otherwise HOLD the trade.  \n\n"
    */ 
    "IMPORTANT:  Respond ONLY with a single JSON object (no code blocks). The JSON must contain the following fields:\n\n"
    "- \"trade_signal\": \"BUY\", \"SELL\", or \"HOLD\"\n"
    "- \"entry_type\": \"IMMEDIATE\", \"LIMIT\", or \"FLAT\" (if market is flat)\n"
    "- \"risk_level\": \"LOW\", \"MEDIUM\", or \"HIGH\"\n"
    "- \"confidence\": a number 0-100\n"
    "- \"stop_loss_pips\": recommended SL in pips\n"
    "- \"take_profit_pips\": recommended TP in pips\n"
    "- \"lot_size\": recommended lot size (<= 1.00)\n"
    "- \"risk_reward_ratio\": numeric ratio (TP/SL)\n"
    "- \"analysis_reasoning\": brief explanation\n\n"
    "IMPORTANT: Respond ONLY with a JSON object. DO NOT use code blocks (e.g., ```json```). The JSON must contain the following fields:\n\n"
    "Example JSON:\n"
    "{\n"
    "  \"trade_signal\": \"BUY\",\n"
    "  \"entry_type\": \"IMMEDIATE\",\n"
    "  \"risk_level\": \"MEDIUM\",\n"
    "  \"confidence\": 75,\n"
    "  \"stop_loss_pips\": 25,\n"
    "  \"take_profit_pips\": 50,\n"
    "  \"lot_size\": 0.5,\n"
    "  \"risk_reward_ratio\": 2.0,\n"
    "  \"analysis_reasoning\": \"The trade is supported by a bullish trend and a key demand zone. Stop loss is below swing low; TP aims for a major resistance.\"\n"
    "}\n\n";
	
	
    string escaped_system_request = system_request;
    StringReplace(escaped_system_request, "\"", "\\\"");
    StringReplace(escaped_system_request, "\n", "\\n");
    StringReplace(escaped_system_request, "\r", "\\r");
	
	
    // Create request without account info in body since it's now in headers
    string request = StringFormat(
        "{\"model\": \"gpt-4o-mini\"," //deepseek-chat | gpt-4o-mini
        "\"messages\": ["
		  "{\"role\": \"system\", \"content\": \"%s\"} ,"
        "  {\"role\": \"user\", \"content\": \"%s\"}"
        "],"
        "\"temperature\": 0,"
        "\"stream\": false }",
		  escaped_system_request,
        escaped_analysis
    );
    
    StringToCharArray(request, post);
    //printf(request);
    int res = WebRequest(
        "POST",
        InpApiEndpoint,
        headers,
        5000,
        post,
        result,
        response_headers
    );
    
    if(res == -1) {
        Print("Error in WebRequest. Error code: ", GetLastError());
        Print("Request: ", request);
        Print("Headers: ", headers);
        return "";
    }
    
    string response = CharArrayToString(result);
    
    // Parse the GPT response
    CJAVal json;
    if(!json.Deserialize(response)) {
        Print("Failed to parse GPT response");
        Print("Raw response: ", response);
        return "";
    }
    
    // Extract the content and verify it's a valid JSON trading signal
    string content = json["choices"][0]["message"]["content"].ToStr();
    
    // Verify the response is valid JSON with required fields
    CJAVal signal_json;
    if(!signal_json.Deserialize(content)) {
        Print("Invalid JSON in GPT response content");
        Print("Content: ", content);
        return "";
    }
    
    // Verify required fields exist
    if(signal_json["trade_signal"].ToStr() == "" || 
       signal_json["entry_type"].ToStr() == "" || 
       signal_json["risk_level"].ToStr() == "" || 
       signal_json["confidence"].ToInt() == "" || 
       signal_json["analysis_reasoning"].ToStr() == "") {
        Print("Missing required fields in GPT response");
        return "";
    }

    Print("Trade signal: ", signal_json["trade_signal"].ToStr());
    Print("Entry type: ", signal_json["entry_type"].ToStr());
    Print("Risk level: ", signal_json["risk_level"].ToStr());
    Print("Confidence: ", signal_json["confidence"].ToInt());
    Print("Analysis reasoning: ", signal_json["analysis_reasoning"].ToStr());
    Print("Stop loss pips: ", signal_json["stop_loss_pips"].ToDbl());
    Print("Take profit pips: ", signal_json["take_profit_pips"].ToDbl());
    Print("Lot size: ", signal_json["lot_size"].ToDbl());
    Print("Risk reward ratio: ", signal_json["risk_reward_ratio"].ToDbl());
    Print("Risk level: ", signal_json["risk_level"].ToStr());
    return content;
}

//+------------------------------------------------------------------+
//| Process the trading signal from GPT                               |
//+------------------------------------------------------------------+
void ProcessTradeSignal(string response) {
    if(response == "") return;
    
    CJAVal json;
    if(!json.Deserialize(response)) {
        Print("Failed to parse JSON response");
        return;
    }
    
    // Get signal details
    string signal = json["trade_signal"].ToStr();
    string entry_type = json["entry_type"].ToStr();
    string risk_level = json["risk_level"].ToStr();
    int confidence = (int)json["confidence"].ToInt();
    string reasoning = json["analysis_reasoning"].ToStr();
    
    // Check if risk level is allowed before proceeding
    if(!IsRiskLevelAllowed(risk_level)) {
        Print("Trade signal ignored - Risk level ", risk_level, 
              " exceeds user preference of ", EnumToString(InpRiskLevel));
        return;
    }
    
    // Get the recommended SL/TP values
    double stop_loss_pips = json["stop_loss_pips"].ToDbl();
    double take_profit_pips = json["take_profit_pips"].ToDbl();
    double recommended_lot = json["lot_size"].ToDbl();
    double risk_reward = json["risk_reward_ratio"].ToDbl();
    
    // Ensure lot size doesn't exceed maximum
    double lot_size = MathMin(recommended_lot, InpLotSize);
    
    // Convert pips to price points
    double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 
                      (SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 || 
                       SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5 ? 10 : 1);
    
    double stop_loss_points = stop_loss_pips * pip_value;
    double take_profit_points = take_profit_pips * pip_value;
    
    // Get current prices
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Only execute if confidence meets minimum requirement
    if(confidence >= InpMinConfidence) {
        if(InpBotType == BOT_AI_INDICATOR) {
            // Always draw signal in indicator mode
            DrawSignal(signal, confidence, bid, TimeCurrent());
            Print("AI Indicator Signal: ", signal, " with ", confidence, "% confidence");
        }
        else {
            // Trading mode - proceed with order placement
            double entry_price = 0;
            double stop_loss = 0;
            double take_profit = 0;
            
            if(signal == "BUY") {
                if(entry_type == "IMMEDIATE") {
                    entry_price = ask;
                    stop_loss = entry_price - stop_loss_points;
                    take_profit = entry_price + take_profit_points;
                    OpenBuyOrder(lot_size, stop_loss, take_profit);
                }
                else if(entry_type == "LIMIT") {
                    entry_price = bid - (pip_value * 2);
                    stop_loss = entry_price - stop_loss_points;
                    take_profit = entry_price + take_profit_points;
                    OpenBuyLimitOrder(lot_size, entry_price, stop_loss, take_profit);
                }
                else {
                    Print("AI Analysis - Flat Market");
                }
            }
            else if(signal == "SELL") {
                if(entry_type == "IMMEDIATE") {
                    entry_price = bid;
                    stop_loss = entry_price + stop_loss_points;
                    take_profit = entry_price - take_profit_points;
                    OpenSellOrder(lot_size, stop_loss, take_profit);
                }
                else if(entry_type == "LIMIT") {
                    entry_price = ask + (pip_value * 2);
                    stop_loss = entry_price + stop_loss_points;
                    take_profit = entry_price - take_profit_points;
                    OpenSellLimitOrder(lot_size, entry_price, stop_loss, take_profit);
                }
                else {
                    Print("AI Analysis - Flat Market");
                }
            }
            else {  // HOLD signal
                Print("AI Analysis - HOLD signal received");
            }
        }
    }
    else {
        if(InpBotType == BOT_AI_INDICATOR) {
            // Draw low confidence signal in indicator mode
            DrawSignal(signal, confidence, bid, TimeCurrent());
            Print("AI Indicator Low Confidence Signal: ", signal, " with ", confidence, "% confidence");
        }
        else {
            Print("Signal ignored - Confidence level ", confidence, 
                  "% below minimum requirement of ", InpMinConfidence, "%");
        }
    }
}


//+------------------------------------------------------------------+
//| Count active trades and pending orders                            |
//+------------------------------------------------------------------+
int CountActiveTrades() {
    int count = 0;
    
    // Count active positions
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionSelectByTicket(PositionGetTicket(i))) {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
                count++;
            }
        }
    }
    
    // Count pending orders
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(OrderGetTicket(i))) {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol) {
                // Check if it's a pending order (BUY_LIMIT, SELL_LIMIT, BUY_STOP, SELL_STOP)
                ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT ||
                   type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP) {
                    count++;
                }
            }
        }
    }
    
    Print("Total active trades and pending orders: ", count);
    return count;
}

//+------------------------------------------------------------------+
//| Order placement helper functions                                   |
//+------------------------------------------------------------------+
bool OpenBuyLimitOrder(double lot, double entry, double sl, double tp) {
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_PENDING;
    request.type = ORDER_TYPE_BUY_LIMIT;
    request.symbol = _Symbol;
    request.volume = lot;
    request.price = entry;
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result = {};
    return OrderSend(request, result);
}

bool OpenSellLimitOrder(double lot, double entry, double sl, double tp) {
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_PENDING;
    request.type = ORDER_TYPE_SELL_LIMIT;
    request.symbol = _Symbol;
    request.volume = lot;
    request.price = entry;
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result = {};
    return OrderSend(request, result);
}

bool OpenBuyStopOrder(double lot, double entry, double sl, double tp) {
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_PENDING;
    request.type = ORDER_TYPE_BUY_STOP;
    request.symbol = _Symbol;
    request.volume = lot;
    request.price = entry;
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result = {};
    return OrderSend(request, result);
}

bool OpenSellStopOrder(double lot, double entry, double sl, double tp) {
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_PENDING;
    request.type = ORDER_TYPE_SELL_STOP;
    request.symbol = _Symbol;
    request.volume = lot;
    request.price = entry;
    request.sl = sl;
    request.tp = tp;
    
    MqlTradeResult result = {};
    return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Enhanced candlestick analysis for a specific timeframe            |
//+------------------------------------------------------------------+
CandleData AnalyzeCandlePattern(int shift, ENUM_TIMEFRAMES timeframe) {
    CandleData candle;
    
    candle.time = iTime(_Symbol, timeframe, shift);
    candle.open = iOpen(_Symbol, timeframe, shift);
    candle.high = iHigh(_Symbol, timeframe, shift);
    candle.low = iLow(_Symbol, timeframe, shift);
    candle.close = iClose(_Symbol, timeframe, shift);
    candle.volume = iVolume(_Symbol, timeframe, shift);
    
    // Calculate candle properties
    candle.bullish = candle.close > candle.open;
    double total_range = candle.high - candle.low;
    
    // Avoid division by zero
    if(total_range == 0) {
        candle.body_size = 0;
        candle.upper_shadow = 0;
        candle.lower_shadow = 0;
        candle.body_ratio = 0;
    } else {
        // Calculate body size
        candle.body_size = MathAbs(candle.close - candle.open);
        
        // Calculate shadows
        if(candle.bullish) {
            candle.upper_shadow = candle.high - candle.close;    // Distance from close to high
            candle.lower_shadow = candle.open - candle.low;      // Distance from open to low
        } else {
            candle.upper_shadow = candle.high - candle.open;     // Distance from open to high
            candle.lower_shadow = candle.close - candle.low;     // Distance from close to low
        }
        
        // Calculate ratios as percentage of total range
        candle.body_ratio = candle.body_size / total_range;
        candle.upper_shadow = candle.upper_shadow / total_range;  // Store as ratio
        candle.lower_shadow = candle.lower_shadow / total_range;  // Store as ratio
    }
    
    // Identify pattern
    if(candle.body_size < total_range * 0.1) {
        if(candle.upper_shadow > candle.lower_shadow * 3)
            candle.pattern = "Long-Legged Doji (Top)";
        else if(candle.lower_shadow > candle.upper_shadow * 3)
            candle.pattern = "Long-Legged Doji (Bottom)";
        else
            candle.pattern = "Doji";
    }
    else if(candle.body_ratio > 0.7) {
        candle.pattern = candle.bullish ? "Strong Bullish Marubozu" : "Strong Bearish Marubozu";
    }
    else {
        candle.pattern = candle.bullish ? "Bullish" : "Bearish";
    }
    
    return candle;
}

//+------------------------------------------------------------------+
//| Detect complex chart patterns                                     |
//+------------------------------------------------------------------+
string DetectComplexPatterns(ENUM_TIMEFRAMES timeframe, int count) {
    PatternInfo patterns[];
    
    // Get price data with bounds checking
    double highs[], lows[], closes[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);
    
    // Add extra candles for pattern context with bounds checking
    int requiredBars = count + 10;
    if(CopyHigh(_Symbol, timeframe, 0, requiredBars, highs) != requiredBars ||
       CopyLow(_Symbol, timeframe, 0, requiredBars, lows) != requiredBars ||
       CopyClose(_Symbol, timeframe, 0, requiredBars, closes) != requiredBars) {
        Print("Failed to copy price data for pattern detection");
        return "Insufficient data for pattern analysis";
    }
    
    // Head and Shoulders Pattern Detection
    if(DetectHeadAndShoulders(highs, lows, closes, timeframe)) {
        PatternInfo pattern;
        pattern.pattern_name = "Head and Shoulders";
        pattern.timeframe = TimeframeToString(timeframe);
        pattern.direction = "bearish";
        pattern.formation_high = SafeArrayGet(highs, ArrayMinimum(highs, 0, 5));
        pattern.target_price = CalculateHSTarget(highs, lows);
        pattern.confidence = CalculatePatternConfidence(pattern.pattern_name, highs, lows);
        ArrayAppend(patterns, pattern);
    }
    
    // Inverse Head and Shoulders
    if(DetectInverseHeadAndShoulders(highs, lows, closes, timeframe)) {
        PatternInfo pattern;
        pattern.pattern_name = "Inverse Head and Shoulders";
        pattern.timeframe = TimeframeToString(timeframe);
        pattern.direction = "bullish";
        pattern.formation_low = SafeArrayGet(lows, ArrayMinimum(lows, 0, 5));
        pattern.target_price = CalculateIHSTarget(highs, lows);
        pattern.confidence = CalculatePatternConfidence(pattern.pattern_name, highs, lows);
        ArrayAppend(patterns, pattern);
    }
    
    // Double Top
    if(DetectDoubleTop(highs, lows, closes)) {
        PatternInfo pattern;
        pattern.pattern_name = "Double Top";
        pattern.timeframe = TimeframeToString(timeframe);
        pattern.direction = "bearish";
        pattern.formation_high = SafeArrayGet(highs, ArrayMaximum(highs, 0, 5));
        pattern.target_price = CalculateDoubleTopTarget(highs, lows);
        pattern.confidence = CalculatePatternConfidence(pattern.pattern_name, highs, lows);
        ArrayAppend(patterns, pattern);
    }
    
    // Triangle Patterns
    string triangleType = DetectTrianglePattern(highs, lows);
    if(triangleType != "") {
        PatternInfo pattern;
        pattern.pattern_name = triangleType + " Triangle";
        pattern.timeframe = TimeframeToString(timeframe);
        pattern.direction = (triangleType == "Ascending") ? "bullish" : 
                          (triangleType == "Descending") ? "bearish" : "neutral";
        pattern.formation_high = SafeArrayGet(highs, ArrayMaximum(highs, 0, 5));
        pattern.formation_low = SafeArrayGet(lows, ArrayMinimum(lows, 0, 5));
        pattern.target_price = CalculateTriangleTarget(highs, lows, triangleType);
        pattern.confidence = CalculatePatternConfidence(pattern.pattern_name, highs, lows);
        ArrayAppend(patterns, pattern);
    }
    
    // Format patterns into string
    string result = "";
    for(int i = 0; i < ArraySize(patterns); i++) {
        result += StringFormat(
            "%s on %s | Direction: %s | Confidence: %d%% | Target: %.5f | Formation High: %.5f | Formation Low: %.5f\n",
            patterns[i].pattern_name,
            patterns[i].timeframe,
            patterns[i].direction,
            patterns[i].confidence,
            patterns[i].target_price,
            patterns[i].formation_high,
            patterns[i].formation_low
        );
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Pattern detection helper functions                                |
//+------------------------------------------------------------------+
bool DetectHeadAndShoulders(const double &highs[], const double &lows[], const double &closes[], ENUM_TIMEFRAMES timeframe) {
    // Check array sizes first
    int size = MathMin(MathMin(ArraySize(highs), ArraySize(lows)), ArraySize(closes));
    if(size < 20) {  // Need minimum data for pattern detection
        return false;
    }
    
    // Look for left shoulder, head, right shoulder formation
    int peaks[];
    FindPeaks(highs, peaks, 5);
    
    if(ArraySize(peaks) < 3) return false;
    
    // Check if middle peak (head) is higher than shoulders
    for(int i = 0; i < ArraySize(peaks) - 2; i++) {
        // Check array bounds before accessing elements
        if(peaks[i] >= size || peaks[i+1] >= size || peaks[i+2] >= size) {
            continue;
        }
        
        if(SafeArrayGet(highs, peaks[i+1]) > SafeArrayGet(highs, peaks[i]) && 
           SafeArrayGet(highs, peaks[i+1]) > SafeArrayGet(highs, peaks[i+2]) &&
           MathAbs(SafeArrayGet(highs, peaks[i]) - SafeArrayGet(highs, peaks[i+2])) < iATR(_Symbol, timeframe, 14) * 2) {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Triangle pattern detection                                        |
//+------------------------------------------------------------------+
string DetectTrianglePattern(const double &highs[], const double &lows[]) {
    double upperTrendSlope = CalculateTrendSlope(highs, 10);
    double lowerTrendSlope = CalculateTrendSlope(lows, 10);
    
    if(MathAbs(upperTrendSlope) < 0.1 && lowerTrendSlope > 0.1)
        return "Ascending";
    else if(upperTrendSlope < -0.1 && MathAbs(lowerTrendSlope) < 0.1)
        return "Descending";
    else if(upperTrendSlope < -0.1 && lowerTrendSlope > 0.1)
        return "Symmetrical";
        
    return "";
}

//+------------------------------------------------------------------+
//| Calculate trend slope                                             |
//+------------------------------------------------------------------+
double CalculateTrendSlope(const double &prices[], int period) {
    // Check array size first
    int size = ArraySize(prices);
    if(size < period) {
        period = size;  // Adjust period if array is smaller than requested period
    }
    if(period < 2) {  // Need at least 2 points for slope calculation
        return 0.0;
    }
    
    double x[], y[];
    ArrayResize(x, period);
    ArrayResize(y, period);
    
    // Fill arrays with bounds checking
    for(int i = 0; i < period && i < size; i++) {
        x[i] = i;
        y[i] = prices[i];
    }
    
    double slope = 0.0, intercept = 0.0;
    CalculateLinearRegression(x, y, slope, intercept);
    return slope;
}

//+------------------------------------------------------------------+
//| Helper function to convert timeframe to string                    |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES timeframe) {
    switch(timeframe) {
        case PERIOD_M15: return "15M";
        case PERIOD_H1:  return "1H";
        case PERIOD_H4:  return "4H";
        case PERIOD_D1:  return "D1";
        default:         return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Calculate pattern confidence level                                |
//+------------------------------------------------------------------+
int CalculatePatternConfidence(string pattern_name, const double &highs[], const double &lows[]) {
    // Check array sizes first
    int size = MathMin(ArraySize(highs), ArraySize(lows));
    if(size < 10) {  // Need minimum data for confidence calculation
        return 70;  // Return base confidence if insufficient data
    }
    
    int confidence = 70; // Base confidence
    
    // Volume confirmation
    long volumes[];
    ArraySetAsSeries(volumes, true);
    if(CopyRealVolume(_Symbol, PERIOD_CURRENT, 0, 10, volumes) > 0) {
        if(ArraySize(volumes) >= 2) {  // Make sure we have at least 2 volume values
            long vol_current = volumes[0];
            long vol_previous = volumes[1];
            double vol_ratio = (double)vol_current / (double)vol_previous;
            if(vol_ratio > 1.5) confidence += 10;
        }
    }
    
    // Trend confirmation
    double ma20[], ma50[];
    ArraySetAsSeries(ma20, true);
    ArraySetAsSeries(ma50, true);
    
    // Get MA values with error checking
    int ma20_copied = CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE), 0, 0, 10, ma20);
    int ma50_copied = CopyBuffer(iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE), 0, 0, 10, ma50);
    
    // Only adjust confidence based on MAs if we successfully copied the data
    if(ma20_copied > 0 && ma50_copied > 0 && ArraySize(ma20) > 0 && ArraySize(ma50) > 0) {
        if(ma20[0] > ma50[0] && pattern_name.Find("bullish") >= 0) confidence += 10;
        if(ma20[0] < ma50[0] && pattern_name.Find("bearish") >= 0) confidence += 10;
    }
    
    // Volume-based confidence adjustment with bounds checking
    if(ArraySize(volumes) >= 2) {
        if(volumes[0] > volumes[1] * 1.5) confidence += 10;
    }
    
    return MathMin(confidence, 100);
}

//+------------------------------------------------------------------+
//| Format historical data with trend indicators                      |
//+------------------------------------------------------------------+
string FormatHistoricalData(const double &values[], string label) {
    string result = StringFormat("%s: ", label);
    
    // Calculate changes and trends
    for(int i = 0; i < ArraySize(values); i++) {
        string trend = "";
        if(i > 0) {
            double change = values[i] - values[i-1];
            trend = change > 0 ? "?" : (change < 0 ? "?" : "?");
        }
        
        result += StringFormat("%.5f%s ", values[i], trend);
        
        // Add line break every 6 values for readability
        if((i + 1) % 6 == 0) result += "\n    ";
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Analyze historical candlestick patterns                           |
//+------------------------------------------------------------------+
void GatherHistoricalCandleData(CandleData &candles[], ENUM_TIMEFRAMES timeframe, int count) {
    if(!SafeArrayResizeCandleData(candles, count, "Historical Candles")) {
        Print("Failed to resize historical candle array");
        return;
    }

    for(int i = 0; i < count; i++) {
        CandleData candle = AnalyzeCandlePattern(i, timeframe);
        if(!SafeArraySetCandle(candles, i, candle)) {
            Print("Failed to set historical candle data at index ", i);
            continue;
        }
    }
}

//+------------------------------------------------------------------+
//| Identify specific candlestick patterns                            |
//+------------------------------------------------------------------+
string IdentifyCandlePattern(CandleData &candles[], int index, ENUM_TIMEFRAMES timeframe) {
    if(index < 2) return "Insufficient data";
    
    CandleData curr = candles[index];
    CandleData prev = candles[index + 1];
    CandleData prev2 = candles[index + 2];
    
    string pattern = "";
    double atr = iATR(_Symbol, timeframe, 14);
    
    // Single Candlestick Patterns
    if(curr.body_size < (curr.high - curr.low) * 0.1) {
        if(curr.upper_shadow > curr.lower_shadow * 3)
            pattern = "Long-Legged Doji (Top)";
        else if(curr.lower_shadow > curr.upper_shadow * 3)
            pattern = "Long-Legged Doji (Bottom)";
        else
            pattern = "Doji";
    }
    else if(curr.lower_shadow > curr.body_size * 2 && curr.upper_shadow < curr.body_size * 0.5) {
        pattern = curr.bullish ? "Hammer" : "Hanging Man";
    }
    else if(curr.upper_shadow > curr.body_size * 2 && curr.lower_shadow < curr.body_size * 0.5) {
        pattern = curr.bullish ? "Inverted Hammer" : "Shooting Star";
    }
    else if(curr.body_ratio > 0.8) {
        pattern = curr.bullish ? "Bullish Marubozu" : "Bearish Marubozu";
    }
    
    // Multiple Candlestick Patterns
    if(index >= 1) {
        // Engulfing Pattern
        if(curr.body_size > prev.body_size) {
            if(curr.bullish && !prev.bullish && curr.open < prev.close && curr.close > prev.open)
                pattern = "Bullish Engulfing";
            else if(!curr.bullish && prev.bullish && curr.open > prev.close && curr.close < prev.open)
                pattern = "Bearish Engulfing";
        }
        
        // Harami Pattern
        if(curr.body_size < prev.body_size * 0.5) {
            if(curr.bullish && !prev.bullish && curr.close < prev.open && curr.open > prev.close)
                pattern = "Bullish Harami";
            else if(!curr.bullish && prev.bullish && curr.open < prev.high && curr.close > prev.low)
                pattern = "Bearish Harami";
        }
    }
    
    // Three Candle Patterns
    if(index >= 2) {
        // Morning Star
        if(!prev2.bullish && prev.body_size < prev2.body_size * 0.3 && curr.bullish &&
           curr.close > (prev2.open + prev2.close) / 2)
            pattern = "Morning Star";
            
        // Evening Star
        if(prev2.bullish && prev.body_size < prev2.body_size * 0.3 && !curr.bullish &&
           curr.close < (prev2.open + prev2.close) / 2)
            pattern = "Evening Star";
            
        // Three White Soldiers
        if(curr.bullish && prev.bullish && prev2.bullish &&
           curr.open > prev.open && prev.open > prev2.open &&
           curr.close > prev.close && prev.close > prev2.close)
            pattern = "Three White Soldiers";
            
        // Three Black Crows
        if(!curr.bullish && !prev.bullish && !prev2.bullish &&
           curr.open < prev.open && prev.open < prev2.open &&
           curr.close < prev.close && prev.close < prev2.close)
            pattern = "Three Black Crows";
    }
    
    return pattern;
}

//+------------------------------------------------------------------+
//| Format candlestick sequence for LLM                               |
//+------------------------------------------------------------------+
string FormatCandleSequence(const CandleData &candles[], string timeframe) {
    string result = StringFormat("\n%s Timeframe Candlestick Sequence:\n", timeframe);
    
    for(int i = 0; i < ArraySize(candles); i++) {
        double total_range = candles[i].high - candles[i].low;
        double upper_shadow_pct = total_range > 0 ? (candles[i].upper_shadow / total_range) * 100 : 0;
        double lower_shadow_pct = total_range > 0 ? (candles[i].lower_shadow / total_range) * 100 : 0;
        
        result += StringFormat(
            "Time: %s | %s | O: %.5f H: %.5f L: %.5f C: %.5f | %s | Body: %.1f%% | Shadows U:%.1f%% L:%.1f%% | Vol: %.2f\n",
            TimeToString(candles[i].time),
            candles[i].bullish ? "BULL" : "BEAR",
            candles[i].open,
            candles[i].high,
            candles[i].low,
            candles[i].close,
            candles[i].pattern,
            candles[i].body_ratio * 100,
            upper_shadow_pct,
            lower_shadow_pct,
            candles[i].volume
        );
        
        // Add visual separator every 4 candles for readability
        if((i + 1) % 4 == 0) result += "--------------------\n";
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Analyze trend across timeframes                                    |
//+------------------------------------------------------------------+
string AnalyzeTrend() {
    double ma20[], ma50[], ma200[];
    ArraySetAsSeries(ma20, true);
    ArraySetAsSeries(ma50, true);
    ArraySetAsSeries(ma200, true);
    
    // Get MA values
    int ma20_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    int ma50_handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    int ma200_handle = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_SMA, PRICE_CLOSE);
    
    CopyBuffer(ma20_handle, 0, 0, 2, ma20);
    CopyBuffer(ma50_handle, 0, 0, 2, ma50);
    CopyBuffer(ma200_handle, 0, 0, 2, ma200);
    
    // Get current price
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Analyze trend based on MA relationships
    string trend = "";
    
    // Strong trend conditions
    if(current_price > ma20[0] && ma20[0] > ma50[0] && ma50[0] > ma200[0]) {
        trend = "Strong Uptrend";
    }
    else if(current_price < ma20[0] && ma20[0] < ma50[0] && ma50[0] < ma200[0]) {
        trend = "Strong Downtrend";
    }
    // Moderate trend conditions
    else if(current_price > ma50[0] && ma50[0] > ma200[0]) {
        trend = "Moderate Uptrend";
    }
    else if(current_price < ma50[0] && ma50[0] < ma200[0]) {
        trend = "Moderate Downtrend";
    }
    // Weak or consolidating conditions
    else if(MathAbs(ma20[0] - ma50[0]) / ma50[0] < 0.01) {
        trend = "Consolidating";
    }
    else {
        trend = "Mixed";
    }
    
    return trend;
}

//+------------------------------------------------------------------+
//| Analyze supply and demand zones                                    |
//+------------------------------------------------------------------+
void AnalyzeSupplyDemandZones(MarketData &data) {
    const int lookback = 100;
    double highs[], lows[];
    long volumes[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(volumes, true);
    
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, highs) != lookback ||
       CopyLow(_Symbol, PERIOD_CURRENT, 0, lookback, lows) != lookback ||
       CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, lookback, volumes) != lookback) {
        Print("Failed to copy price data for zone analysis");
        return;
    }
    
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double avgVolume = 0;
    for(int i = 0; i < lookback; i++) avgVolume += volumes[i];
    avgVolume /= lookback;
    
    // Clear existing zones
    ArrayResize(data.supply_zones, 0);
    ArrayResize(data.demand_zones, 0);
    
    // Find zones
    for(int i = 1; i < lookback-1; i++) {
        // Supply zone detection
        if(highs[i] > highs[i-1] && highs[i] > highs[i+1] && volumes[i] > avgVolume * 1.5) {
            string zone = StringFormat("%.5f-%.5f", highs[i] - atr*0.5, highs[i] + atr*0.5);
                ArrayResize(data.supply_zones, ArraySize(data.supply_zones) + 1);
            data.supply_zones[ArraySize(data.supply_zones)-1] = zone;
        }
        
        // Demand zone detection
        if(lows[i] < lows[i-1] && lows[i] < lows[i+1] && volumes[i] > avgVolume * 1.5) {
            string zone = StringFormat("%.5f-%.5f", lows[i] - atr*0.5, lows[i] + atr*0.5);
                ArrayResize(data.demand_zones, ArraySize(data.demand_zones) + 1);
            data.demand_zones[ArraySize(data.demand_zones)-1] = zone;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate average of array                                         |
//+------------------------------------------------------------------+
double ArrayAverage(const long &array[]) {
    double sum = 0.0;
    const int size = ArraySize(array);
    
    for(int i = 0; i < size; i++) {
        sum += (double)array[i];  // Explicit cast to double
    }
    
    return sum / (double)size;
}

//+------------------------------------------------------------------+
//| Calculate pivot point for given timeframe                          |
//+------------------------------------------------------------------+
double CalculatePivotPoint(ENUM_TIMEFRAMES timeframe) {
    double high = iHigh(_Symbol, timeframe, 1);
    double low = iLow(_Symbol, timeframe, 1);
    double close = iClose(_Symbol, timeframe, 1);
    
    return (high + low + close) / 3;
}

//+------------------------------------------------------------------+
//| Analyze candlestick patterns across timeframes                     |
//+------------------------------------------------------------------+
string AnalyzeCandlePatterns() {
    string patterns = "";
    const int lookback = 5;  // Number of candles to analyze for patterns
    
    // Arrays to store candle data
    double opens[], highs[], lows[], closes[];
    ArraySetAsSeries(opens, true);
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);
    
    // Get data for current timeframe with error checking
    if(CopyOpen(_Symbol, PERIOD_CURRENT, 0, lookback, opens) != lookback ||
       CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, highs) != lookback ||
       CopyLow(_Symbol, PERIOD_CURRENT, 0, lookback, lows) != lookback ||
       CopyClose(_Symbol, PERIOD_CURRENT, 0, lookback, closes) != lookback) {
        return "Error: Insufficient data for pattern analysis";
    }
    
    // Continue with pattern analysis only if we have enough data
    int size = ArraySize(closes);
    if(size < lookback) {
        return "Error: Insufficient data for pattern analysis";
    }
    
    // Check for various candlestick patterns
    
    // Single Candlestick Patterns
    double body = MathAbs(closes[0] - opens[0]);
    double upper_shadow = highs[0] - MathMax(opens[0], closes[0]);
    double lower_shadow = MathMin(opens[0], closes[0]) - lows[0];
    double total_range = highs[0] - lows[0];
    
    // Doji
    if(body < total_range * 0.1) {
        if(upper_shadow > lower_shadow * 3)
            patterns += "Doji Star (Top)\n";
        else if(lower_shadow > upper_shadow * 3)
            patterns += "Dragonfly Doji\n";
        else
            patterns += "Doji\n";
    }
    
    // Hammer/Hanging Man
    if(lower_shadow > body * 2 && upper_shadow < body * 0.5) {
        if(closes[0] > opens[0])
            patterns += "Hammer (Potential Reversal)\n";
        else
            patterns += "Hanging Man (Warning)\n";
    }
    
    // Shooting Star/Inverted Hammer
    if(upper_shadow > body * 2 && lower_shadow < body * 0.5) {
        if(closes[0] < opens[0])
            patterns += "Shooting Star\n";
        else
            patterns += "Inverted Hammer\n";
    }
    
    // Two Candlestick Patterns
    if(lookback >= 2) {
        // Engulfing
        if(body > MathAbs(closes[1] - opens[1])) {
            if(closes[0] > opens[0] && closes[1] < opens[1] &&
               opens[0] < closes[1] && closes[0] > opens[1])
                patterns += "Bullish Engulfing\n";
            else if(closes[0] < opens[0] && closes[1] > opens[1] &&
                    opens[0] > closes[1] && closes[0] < opens[1])
                patterns += "Bearish Engulfing\n";
        }
        
        // Harami
        if(body < MathAbs(closes[1] - opens[1]) * 0.5) {
            if(closes[1] < opens[1] && closes[0] > opens[0] &&
               opens[0] > closes[1] && closes[0] < opens[1])
                patterns += "Bullish Harami\n";
            else if(closes[1] > opens[1] && closes[0] < opens[0] &&
                    opens[0] < closes[1] && closes[0] > opens[1])
                patterns += "Bearish Harami\n";
        }
    }
    
    // Three Candlestick Patterns
    if(lookback >= 3) {
        // Morning Star
        if(closes[2] < opens[2] &&                           // First candle bearish
           MathAbs(closes[1] - opens[1]) < body * 0.3 &&    // Small middle candle
           closes[0] > opens[0] &&                           // Third candle bullish
           closes[0] > (opens[2] + closes[2]) / 2)          // Closed above midpoint of first candle
            patterns += "Morning Star\n";
            
        // Evening Star
        if(closes[2] > opens[2] &&                           // First candle bullish
           MathAbs(closes[1] - opens[1]) < body * 0.3 &&    // Small middle candle
           closes[0] < opens[0] &&                           // Third candle bearish
           closes[0] < (opens[2] + closes[2]) / 2)          // Closed below midpoint of first candle
            patterns += "Evening Star\n";
            
        // Three White Soldiers
        if(closes[2] > opens[2] && closes[1] > opens[1] && closes[0] > opens[0] &&
           opens[1] > opens[2] && opens[0] > opens[1] &&
           closes[1] > closes[2] && closes[0] > closes[1])
            patterns += "Three White Soldiers\n";
            
        // Three Black Crows
        if(closes[2] < opens[2] && closes[1] < opens[1] && closes[0] < opens[0] &&
           opens[1] < opens[2] && opens[0] < opens[1] &&
           closes[1] < closes[2] && closes[0] < closes[1])
            patterns += "Three Black Crows\n";
    }
    
    if(patterns == "")
        patterns = "No significant candlestick patterns detected";
        
    return patterns;
}

//+------------------------------------------------------------------+
//| Analyze technical patterns                                         |
//+------------------------------------------------------------------+
string AnalyzeTechnicalPatterns() {
    string patterns = "";
    const int lookback = 100;  // Number of candles to analyze
    
    // Arrays to store price data
    double highs[], lows[], closes[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);
    
    // Copy price data with error checking
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, lookback, highs) != lookback ||
       CopyLow(_Symbol, PERIOD_CURRENT, 0, lookback, lows) != lookback ||
       CopyClose(_Symbol, PERIOD_CURRENT, 0, lookback, closes) != lookback) {
        Print("Error copying price data: ", GetLastError());
        return "Error: Insufficient price data";
    }
    
    // Find peaks and troughs with array size check
    int peaks[], troughs[];
    if(ArraySize(highs) >= 10) {  // Ensure minimum data for pattern detection
        FindPeaks(highs, peaks, 5);  // Minimum 5 bars between peaks
        FindPeaks(lows, troughs, 5);  // Minimum 5 bars between troughs
    } else {
        return "Error: Insufficient data for pattern detection";
    }
    
    // Head and Shoulders with array bounds check
    if(ArraySize(highs) >= 20 && ArraySize(lows) >= 20 && ArraySize(closes) >= 20) {
        if(DetectHeadAndShoulders(highs, lows, closes, PERIOD_CURRENT)) {
            double target = CalculateHSTarget(highs, lows);
            patterns += StringFormat("Head and Shoulders pattern detected. Target: %.5f\n", target);
        }
        
        // Inverse Head and Shoulders
        if(DetectInverseHeadAndShoulders(highs, lows, closes, PERIOD_CURRENT)) {
            double target = CalculateIHSTarget(highs, lows);
            patterns += StringFormat("Inverse Head and Shoulders pattern detected. Target: %.5f\n", target);
        }
        
        // Double Top
        if(DetectDoubleTop(highs, lows, closes)) {
            double target = CalculateDoubleTopTarget(highs, lows);
            patterns += StringFormat("Double Top pattern detected. Target: %.5f\n", target);
        }
        
        // Double Bottom
        if(DetectDoubleBottom(highs, lows, closes)) {
            double target = CalculateDoubleBottomTarget(highs, lows);
            patterns += StringFormat("Double Bottom pattern detected. Target: %.5f\n", target);
        }
    }
    
    // Triangle Patterns with array bounds check
    if(ArraySize(highs) >= 20 && ArraySize(lows) >= 20) {
        string triangleType = DetectTrianglePattern(highs, lows);
        if(triangleType != "") {
            double target = CalculateTriangleTarget(highs, lows, triangleType);
            patterns += StringFormat("%s Triangle pattern detected. Target: %.5f\n", triangleType, target);
        }
    }
    
    // Trend Lines with array bounds check
    if(ArraySize(closes) >= 2) {
        double x[], y[];
        ArrayResize(x, ArraySize(closes));
        ArrayResize(y, ArraySize(closes));
        for(int i = 0; i < ArraySize(closes); i++) {
            x[i] = i;
            y[i] = closes[i];
        }
        
        double slope, intercept;
        CalculateLinearRegression(x, y, slope, intercept);
        string trendStrength = "";
        
        if(MathAbs(slope) < 0.0001)
            trendStrength = "Ranging";
        else if(slope > 0)
            trendStrength = slope > 0.001 ? "Strong Uptrend" : "Weak Uptrend";
        else
            trendStrength = slope < -0.001 ? "Strong Downtrend" : "Weak Downtrend";
        
        patterns += "Trend Analysis: " + trendStrength + "\n";
    }
    
    // Check for price channels with array bounds check
    if(ArraySize(highs) >= 20 && ArraySize(lows) >= 20) {
        double channelTop = 0, channelBottom = 0;
        if(DetectPriceChannel(highs, lows, channelTop, channelBottom)) {
            patterns += StringFormat("Price Channel detected: Top %.5f, Bottom %.5f\n", 
                                   channelTop, channelBottom);
        }
    }
    
    if(patterns == "")
        patterns = "No significant technical patterns detected";
    
    return patterns;
}

//+------------------------------------------------------------------+
//| Detect Double Bottom pattern                                       |
//+------------------------------------------------------------------+
bool DetectDoubleBottom(const double &highs[], const double &lows[], const double &closes[]) {
    const int lookback = 50;  // Look back period
    const double tolerance = 0.0002;  // Price tolerance for bottoms
    
    // Check array sizes first
    int size = ArraySize(lows);
    if(size < lookback || ArraySize(highs) < lookback || ArraySize(closes) < lookback) {
        return false;
    }
    
    // Ensure we have enough bars for pattern detection
    for(int i = 5; i < MathMin(lookback - 5, size - 2); i++) {
        // Check array bounds before accessing elements
        if(i >= size - 1) break;
        
        // Find first bottom
        if(lows[i] < lows[i-1] && lows[i] < lows[i+1]) {
            // Look for second bottom
            for(int j = i + 5; j < MathMin(lookback - 2, size - 2); j++) {
                // Check array bounds before accessing elements
                if(j >= size - 1) break;
                
                if(lows[j] < lows[j-1] && lows[j] < lows[j+1]) {
                    // Check if bottoms are at similar levels
                    if(MathAbs(lows[i] - lows[j]) < tolerance) {
                        // Check if there's a higher peak between bottoms
                        double maxBetween = lows[i];
                        
                        // Ensure k stays within array bounds
                        for(int k = i + 1; k < j && k < size; k++) {
                            maxBetween = MathMax(maxBetween, highs[k]);
                        }
                        
                        if(maxBetween > lows[i] * 1.02) {  // At least 2% higher
                            return true;
                        }
                    }
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calculate target for Double Bottom pattern                         |
//+------------------------------------------------------------------+
double CalculateDoubleBottomTarget(const double &highs[], const double &lows[]) {
    // Check array sizes first
    int size = MathMin(ArraySize(highs), ArraySize(lows));
    if(size < 2) {
        return 0.0;  // Return 0 if insufficient data
    }
    
    double lowestPoint = DBL_MAX;
    double highestPoint = -DBL_MAX;
    const int lookback = MathMin(50, size);  // Use either 50 or array size, whichever is smaller
    
    // Find lowest and highest points in pattern with bounds checking
    for(int i = 0; i < lookback; i++) {
        if(i < size) {  // Additional bounds check
            lowestPoint = MathMin(lowestPoint, lows[i]);
            highestPoint = MathMax(highestPoint, highs[i]);
        }
    }
    
    // Validate the calculated points
    if(lowestPoint == DBL_MAX || highestPoint == -DBL_MAX) {
        return 0.0;  // Return 0 if no valid points found
    }
    
    // Target is typically the height of pattern added to breakout point
    double patternHeight = highestPoint - lowestPoint;
    return highestPoint + patternHeight;
}

//+------------------------------------------------------------------+
//| Detect Price Channel                                              |
//+------------------------------------------------------------------+
bool DetectPriceChannel(const double &highs[], const double &lows[], double &channelTop, double &channelBottom) {
    // Check array sizes first
    int size = MathMin(ArraySize(highs), ArraySize(lows));
    if(size < 20) {  // Need at least 20 bars for reliable channel
        return false;
    }
    
    const int lookback = MathMin(20, size);  // Look back period for channel
    const double tolerance = 0.0002;  // Tolerance for parallel lines
    
    // Find potential channel boundaries with bounds checking
    int highIndex = ArrayMinimum(highs, 0, lookback);
    int lowIndex = ArrayMaximum(lows, 0, lookback);
    
    if(highIndex < 0 || lowIndex < 0 || highIndex >= size || lowIndex >= size) {
        return false;
    }
    
    double upperLine = highs[highIndex];
    double lowerLine = lows[lowIndex];
    
    // Count touches of channel boundaries
    int upperTouches = 0;
    int lowerTouches = 0;
    
    for(int i = 0; i < lookback && i < size; i++) {
        if(MathAbs(highs[i] - upperLine) < tolerance)
            upperTouches++;
        if(MathAbs(lows[i] - lowerLine) < tolerance)
            lowerTouches++;
    }
    
    // Channel is valid if we have at least 2 touches on each boundary
    if(upperTouches >= 2 && lowerTouches >= 2) {
        channelTop = upperLine;
        channelBottom = lowerLine;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Find peaks in price array                                         |
//+------------------------------------------------------------------+
void FindPeaks(const double &array[], int &peaks[], int min_distance) {
    int size = ArraySize(array);
    ArrayResize(peaks, 0);
    
    if(size < 2 * min_distance + 1) {
        Print("Insufficient data for peak detection");
        return;
    }
    
    for(int i = min_distance; i < size - min_distance; i++) {
        bool isPeak = true;
        
        for(int j = 1; j <= min_distance && isPeak; j++) {
            if(i-j < 0 || i+j >= size) {
                isPeak = false;
                break;
            }
            
            if(SafeArrayGet(array, i) <= SafeArrayGet(array, i-j) || 
               SafeArrayGet(array, i) <= SafeArrayGet(array, i+j)) {
                isPeak = false;
            }
        }
        
        if(isPeak) {
            int peakCount = ArraySize(peaks);
            if(!ArrayResize(peaks, peakCount + 1)) {
                Print("Failed to resize peaks array");
                return;
            }
            peaks[peakCount] = i;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Head and Shoulders target price                          |
//+------------------------------------------------------------------+
double CalculateHSTarget(const double &highs[], const double &lows[]) {
    // Check array sizes first
    int size = MathMin(ArraySize(highs), ArraySize(lows));
    if(size < 50) {  // Need minimum data for reliable calculation
        return 0.0;
    }
    
    const int lookback = MathMin(50, size);
    
    // Initialize variables
    double leftShoulder = 0, head = 0, rightShoulder = 0;
    double neckline = 0;
    int headIndex = -1, leftShoulderIndex = -1, rightShoulderIndex = -1;
    
    // Find head (highest point) with bounds checking
    headIndex = ArrayMaximum(highs, 0, lookback);
    if(headIndex < 0 || headIndex >= size) {
        return 0.0;
    }
    head = highs[headIndex];
    
    // Find left shoulder with bounds checking
    if(headIndex + 1 < size && headIndex >= 10) {
        leftShoulderIndex = ArrayMaximum(highs, headIndex + 1, headIndex - 10);
        if(leftShoulderIndex >= 0 && leftShoulderIndex < size) {
            leftShoulder = highs[leftShoulderIndex];
        }
    }
    
    // Find right shoulder with bounds checking
    if(headIndex > 0) {
        rightShoulderIndex = ArrayMaximum(highs, 0, headIndex - 1);
        if(rightShoulderIndex >= 0 && rightShoulderIndex < size) {
            rightShoulder = highs[rightShoulderIndex];
        }
    }
    
    // Validate shoulder indices
    if(leftShoulderIndex < 0 || rightShoulderIndex < 0) {
        return 0.0;
    }
    
    // Calculate neckline with bounds checking
    int leftTroughIndex = ArrayMinimum(lows, leftShoulderIndex, 
                                     MathMin(headIndex - leftShoulderIndex, size - leftShoulderIndex));
    int rightTroughIndex = ArrayMinimum(lows, headIndex, 
                                      MathMin(rightShoulderIndex - headIndex, size - headIndex));
    
    if(leftTroughIndex >= 0 && leftTroughIndex < size && 
       rightTroughIndex >= 0 && rightTroughIndex < size) {
        double leftTrough = lows[leftTroughIndex];
        double rightTrough = lows[rightTroughIndex];
        neckline = (leftTrough + rightTrough) / 2;
    } else {
        return 0.0;
    }
    
    // Calculate pattern height
    double patternHeight = head - neckline;
    if(patternHeight <= 0) {
        return 0.0;
    }
    
    // Target is typically the height of pattern projected down from neckline
    return neckline - patternHeight;
}

//+------------------------------------------------------------------+
//| Calculate Inverse Head and Shoulders target price                  |
//+------------------------------------------------------------------+
double CalculateIHSTarget(const double &highs[], const double &lows[]) {
    // Check array sizes first
    int size = MathMin(ArraySize(highs), ArraySize(lows));
    if(size < 50) {  // Need minimum data for reliable calculation
        return 0.0;
    }
    
    const int lookback = MathMin(50, size);
    
    // Initialize variables
    double leftShoulder = DBL_MAX, head = DBL_MAX, rightShoulder = DBL_MAX;
    double neckline = 0;
    int headIndex = -1, leftShoulderIndex = -1, rightShoulderIndex = -1;
    
    // Find head (lowest point) with bounds checking
    headIndex = ArrayMinimum(lows, 0, lookback);
    if(headIndex < 0 || headIndex >= size) {
        return 0.0;
    }
    head = lows[headIndex];
    
    // Find left shoulder with bounds checking
    if(headIndex + 1 < size && headIndex >= 10) {
        leftShoulderIndex = ArrayMinimum(lows, headIndex + 1, headIndex - 10);
        if(leftShoulderIndex >= 0 && leftShoulderIndex < size) {
            leftShoulder = lows[leftShoulderIndex];
        } else {
            return 0.0;
        }
    } else {
        return 0.0;
    }
    
    // Find right shoulder with bounds checking
    if(headIndex > 0) {
        rightShoulderIndex = ArrayMinimum(lows, 0, headIndex - 1);
        if(rightShoulderIndex >= 0 && rightShoulderIndex < size) {
            rightShoulder = lows[rightShoulderIndex];
        } else {
            return 0.0;
        }
    } else {
        return 0.0;
    }
    
    // Calculate neckline with bounds checking
    int leftPeakIndex = ArrayMaximum(highs, leftShoulderIndex, 
                                   MathMin(headIndex - leftShoulderIndex, size - leftShoulderIndex));
    int rightPeakIndex = ArrayMaximum(highs, headIndex, 
                                    MathMin(rightShoulderIndex - headIndex, size - headIndex));
    
    if(leftPeakIndex < 0 || rightPeakIndex < 0 || 
       leftPeakIndex >= size || rightPeakIndex >= size) {
        return 0.0;
    }
    
    double leftPeak = highs[leftPeakIndex];
    double rightPeak = highs[rightPeakIndex];
    neckline = (leftPeak + rightPeak) / 2;
    
    // Validate the pattern
    if(leftShoulder == DBL_MAX || head == DBL_MAX || rightShoulder == DBL_MAX || 
       neckline <= head || head >= leftShoulder || head >= rightShoulder) {
        return 0.0;
    }
    
    // Calculate pattern height and target
    double patternHeight = neckline - head;
    if(patternHeight <= 0) {
        return 0.0;
    }
    
    return neckline + patternHeight;
}

//+------------------------------------------------------------------+
//| Calculate Double Top target price                                  |
//+------------------------------------------------------------------+
double CalculateDoubleTopTarget(const double &highs[], const double &lows[]) {
    // Check array sizes first
    int size = MathMin(ArraySize(highs), ArraySize(lows));  // Remove closes from size calculation
    if(size < 50) {  // Need minimum data for reliable calculation
        return 0.0;
    }
    
    const int lookback = MathMin(50, size);  // Use either 50 or array size, whichever is smaller
    double firstTop = 0, secondTop = 0;
    double neckline = DBL_MAX;
    int firstTopIndex = -1, secondTopIndex = -1;
    
    // Find the two tops with bounds checking
    for(int i = lookback - 1; i >= 2; i--) {  // Start at lookback-1 and ensure we have room for i-1 and i+1
        // Check array bounds before accessing elements
        if(i >= size || i-1 < 0 || i+1 >= size) continue;
        
        // Find first top
        if(highs[i] > highs[i-1] && highs[i] > highs[i+1]) {
            // Look for second top
            for(int j = i + 5; j < lookback - 2; j++) {
                // Check array bounds before accessing elements
                if(j >= size || j-1 < 0 || j+1 >= size) continue;
                
                if(highs[j] > highs[j-1] && highs[j] > highs[j+1]) {
                    // Check if tops are at similar levels
                    if(MathAbs(highs[i] - highs[j]) < 0.0002) {
                        // Check if there's a lower trough between tops
                        double minBetween = highs[i];
                        
                        // Ensure k stays within array bounds
                        for(int k = i + 1; k < j && k < size; k++) {
                            minBetween = MathMin(minBetween, lows[k]);
                        }
                        
                        // Verify the pattern with a minimum 2% drop between tops
                        if(minBetween < highs[i] * 0.98) {
                            // Check for potential breakdown below the neckline
                            if(j + 1 < size && lows[j + 1] < minBetween) {
                                return minBetween - (highs[i] - minBetween);  // Project the target
                            }
                        }
                    }
                }
            }
        }
    }
    
        return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate Triangle pattern target price                            |
//+------------------------------------------------------------------+
double CalculateTriangleTarget(const double &highs[], const double &lows[], string type) {
    // Check array sizes first
    int size = MathMin(ArraySize(highs), ArraySize(lows));
    if(size < 20) {  // Need minimum data for reliable calculation
        return 0.0;
    }
    
    const int lookback = MathMin(20, size);  // Use either 20 or array size, whichever is smaller
    
    // Ensure we have enough data before accessing array elements
    if(lookback < 2) {
        return 0.0;
    }
    
    // Calculate heights with bounds checking
    double initialHeight = 0.0;
    double currentHeight = 0.0;
    double breakoutPrice = 0.0;
    
    if(lookback - 1 < size && lookback - 1 >= 0) {
        initialHeight = highs[lookback-1] - lows[lookback-1];
    }
    
    if(0 < size) {
        currentHeight = highs[0] - lows[0];
        breakoutPrice = highs[0];  // Default to current high
    } else {
        return 0.0;
    }
    
    // Calculate target based on triangle type
    if(type == "Ascending") {
        // Target is typically the height of the base added to breakout point
        return breakoutPrice + initialHeight;
    }
    else if(type == "Descending") {
        if(0 < size) {
            breakoutPrice = lows[0];  // Use current low for descending triangle
        }
        return breakoutPrice - initialHeight;
    }
    else if(type == "Symmetrical") {
        // For symmetrical triangles, use the height at pattern start
        if(1 < size && highs[0] > highs[1]) {  // Upward breakout
            return breakoutPrice + initialHeight;
        }
        else {  // Downward breakout
            if(0 < size) {
                breakoutPrice = lows[0];
            }
            return breakoutPrice - initialHeight;
        }
    }
    
    return 0.0;  // Return 0 if pattern type is not recognized
}

//+------------------------------------------------------------------+
//| Calculate linear regression slope and intercept                    |
//+------------------------------------------------------------------+
void CalculateLinearRegression(const double &x[], const double &y[], double &slope, double &intercept) {
    int n = MathMin(ArraySize(x), ArraySize(y));
    if(n < 2) {
        slope = 0;
        intercept = 0;
        return;
    }
    
    double sum_x = 0;
    double sum_y = 0;
    double sum_xy = 0;
    double sum_xx = 0;
    
    // Calculate sums with bounds checking
    for(int i = 0; i < n; i++) {
        sum_x += x[i];
        sum_y += y[i];
        sum_xy += x[i] * y[i];
        sum_xx += x[i] * x[i];
    }
    
    // Calculate slope and intercept using least squares method
    double denominator = (n * sum_xx - sum_x * sum_x);
    if(MathAbs(denominator) < 0.000001) {  // Avoid division by zero
        slope = 0;
        intercept = sum_y / n;
        return;
    }
    
    slope = (n * sum_xy - sum_x * sum_y) / denominator;
    intercept = (sum_y - slope * sum_x) / n;
}

//+------------------------------------------------------------------+
//| Detect Inverse Head and Shoulders pattern                          |
//+------------------------------------------------------------------+
bool DetectInverseHeadAndShoulders(const double &highs[], const double &lows[], const double &closes[], ENUM_TIMEFRAMES timeframe) {
    // Look for left shoulder, head, right shoulder formation
    int troughs[];
    FindPeaks(lows, troughs, 5);  // Find valleys with minimum 5 bars between them
    
    if(ArraySize(troughs) < 3) return false;
    
    double atr = iATR(_Symbol, timeframe, 14);
    
    // Check for inverse head and shoulders pattern
    for(int i = 0; i < ArraySize(troughs) - 2; i++) {
        // Get the three potential points
        double leftShoulder = lows[troughs[i]];
        double head = lows[troughs[i+1]];
        double rightShoulder = lows[troughs[i+2]];
        
        // Check if head is lower than shoulders
        if(head < leftShoulder && head < rightShoulder) {
            // Check if shoulders are at similar levels (within 1 ATR)
            if(MathAbs(leftShoulder - rightShoulder) < atr) {
                // Check for neckline break
                int necklineIndex = troughs[i+2] + 1;  // Look for breakout after right shoulder
                if(necklineIndex < ArraySize(closes)) {
                    double neckline = MathMax(highs[troughs[i]], highs[troughs[i+2]]);
                    if(closes[necklineIndex] > neckline) {
                        return true;
                    }
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Double Top pattern                                         |
//+------------------------------------------------------------------+
bool DetectDoubleTop(const double &highs[], const double &lows[], const double &closes[]) {
    // Check array sizes first
    int size = MathMin(MathMin(ArraySize(highs), ArraySize(lows)), ArraySize(closes));
    if(size < 50) {  // Need minimum data for reliable pattern detection
        return false;
    }
    
    const int lookback = MathMin(50, size);  // Use smaller of 50 or array size
    const double tolerance = 0.0002;  // Price tolerance for tops
    
    // Ensure we have enough bars for pattern detection
    for(int i = 5; i < lookback - 5; i++) {
        // Check array bounds before accessing elements
        if(i >= size || i-1 < 0 || i+1 >= size) continue;
        
        // Find first top
        if(highs[i] > highs[i-1] && highs[i] > highs[i+1]) {
            // Look for second top
            for(int j = i + 5; j < lookback - 2; j++) {
                // Check array bounds before accessing elements
                if(j >= size || j-1 < 0 || j+1 >= size) continue;
                
                if(highs[j] > highs[j-1] && highs[j] > highs[j+1]) {
                    // Check if tops are at similar levels
                    if(MathAbs(highs[i] - highs[j]) < tolerance) {
                        // Check if there's a lower trough between tops
                        double minBetween = highs[i];
                        
                        // Ensure k stays within array bounds
                        for(int k = i + 1; k < j && k < size; k++) {
                            minBetween = MathMin(minBetween, lows[k]);
                        }
                        
                        // Verify the pattern with a minimum 2% drop between tops
                        if(minBetween < highs[i] * 0.98) {
                            // Check for potential breakdown below the neckline
                            if(j + 1 < size) {
                                if(closes[j + 1] < minBetween) {
                                    return true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Open a buy market order with validation                           |
//+------------------------------------------------------------------+
bool OpenBuyOrder(double lot, double sl, double tp) {
    // Validate parameters
    if(lot <= 0) {
        Print("Invalid lot size: ", lot);
        return false;
    }
    
    // Get symbol properties
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Normalize lot size
    lot = MathRound(lot / lot_step) * lot_step;
    lot = MathMax(min_lot, MathMin(max_lot, lot));
    
    // Get current prices
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Validate stop loss and take profit
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double stops_level = point * SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    // Adjust SL and TP if they're too close to current price
    if(sl > 0) {
        double min_sl = bid - stops_level;
        if(sl > min_sl) {
            sl = min_sl;
        }
    }
    
    if(tp > 0) {
        double min_tp = ask + stops_level;
        if(tp < min_tp) {
            tp = min_tp;
        }
    }
    
    // Prepare the trade request
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    request.deviation = 10;
    request.sl = sl;
    request.tp = tp;
    request.magic = 123456;
    request.comment = "AI Buy Order";
    request.type_filling = ORDER_FILLING_FOK;
    
    // Initialize the result object
    MqlTradeResult result = {};
    
    // Send the trade request
    bool success = OrderSend(request, result);
    
    // Handle the result
    if(!success) {
        int error = GetLastError();
        string error_message;
        StringConcatenate(error_message, "Error code: ", error);  // Use StringConcatenate instead
        
        Print("Failed to open buy order: ", error_message);
        Print("Ask: ", ask, " Bid: ", bid, " Lot: ", lot, " SL: ", sl, " TP: ", tp);
        return false;
    }
    
    if(result.retcode == TRADE_RETCODE_DONE) {
        Print("Buy order opened successfully: ", result.order, 
              " Lot: ", lot,
              " Entry: ", ask,
              " SL: ", sl,
              " TP: ", tp);
        return true;
    }
    else {
        Print("Error opening buy order. Return code: ", result.retcode,
              " Comment: ", result.comment);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                       |
//+------------------------------------------------------------------+
bool IsTradeAllowed() {
    // Check if Expert Advisors are allowed to trade
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Print("Trading is not allowed in the terminal");
        return false;
    }
    
    // Check if trading is allowed for this symbol
    if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE)) {
        Print("Trading is not allowed for symbol ", _Symbol);
        return false;
    }
    
    // Check if it's a normal market (not testing)
    if(MQLInfoInteger(MQL_TRADE_ALLOWED) == false) {
        Print("Trading is not allowed - please check settings");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize array with size check and default values                |
//+------------------------------------------------------------------+
bool InitializeArray(double &array[], int size, string arrayName) {
    if(!ArrayResize(array, size)) {
        Print("Failed to resize ", arrayName, " to size ", size);
        return false;
    }
    ArrayInitialize(array, 0.0);
    return true;
}

//+------------------------------------------------------------------+
//| Copy indicator buffer with error checking                          |
//+------------------------------------------------------------------+
bool CopyIndicatorBuffer(int handle, int buffer_num, int start_pos, int count, 
                        double &buffer[], string indicatorName) {
    if(handle == INVALID_HANDLE) {
        Print("Invalid handle for ", indicatorName);
        return false;
    }
    
    if(CopyBuffer(handle, buffer_num, start_pos, count, buffer) <= 0) {
        Print("Failed to copy buffer for ", indicatorName, 
              ". Error code: ", GetLastError());
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Safe CandleData array access with bounds checking                  |
//+------------------------------------------------------------------+
CandleData SafeArrayGetCandle(const CandleData &array[], int index) {
    CandleData defaultCandle;  // Will be initialized with zeros/empty values
    if(index < 0 || index >= ArraySize(array)) {
        Print("Warning: Attempted to access CandleData array out of bounds. Index: ", index, ", Size: ", ArraySize(array));
        return defaultCandle;
    }
    return array[index];
}

//+------------------------------------------------------------------+
//| Safe CandleData array assignment with bounds checking              |
//+------------------------------------------------------------------+
bool SafeArraySetCandle(CandleData &array[], int index, CandleData &value) {
    if(index < 0 || index >= ArraySize(array)) {
        Print("Warning: Attempted to set CandleData array out of bounds. Index: ", index, ", Size: ", ArraySize(array));
        return false;
    }
    array[index] = value;
    return true;
}

//+------------------------------------------------------------------+
//| Convert array to string                                           |
//+------------------------------------------------------------------+
string ArrayToString(const string &array[]) {
    string result = "";
    for(int i = 0; i < ArraySize(array); i++) {
        if(i > 0) result += ", ";
        result += array[i];
    }
    return result == "" ? "None" : result;
}

//+------------------------------------------------------------------+
//| Open a sell market order with validation                          |
//+------------------------------------------------------------------+
bool OpenSellOrder(double lot, double sl, double tp) {
    // Validate parameters
    if(lot <= 0) {
        Print("Invalid lot size: ", lot);
        return false;
    }
    
    // Get symbol properties
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Normalize lot size
    lot = MathRound(lot / lot_step) * lot_step;
    lot = MathMax(min_lot, MathMin(max_lot, lot));
    
    // Get current prices
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Validate stop loss and take profit
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double stops_level = point * SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    
    // Adjust SL and TP if they're too close to current price
    if(sl > 0) {
        double min_sl = ask + stops_level;
        if(sl < min_sl) {
            sl = min_sl;
        }
    }
    
    if(tp > 0) {
        double min_tp = bid - stops_level;
        if(tp > min_tp) {
            tp = min_tp;
        }
    }
    
    // Prepare the trade request
    MqlTradeRequest request = {};
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    request.deviation = 10;
    request.sl = sl;
    request.tp = tp;
    request.magic = 123456;
    request.comment = "AI Sell Order";
    request.type_filling = ORDER_FILLING_FOK;
    
    // Initialize the result object
    MqlTradeResult result = {};
    
    // Send the trade request
    bool success = OrderSend(request, result);
    
    // Handle the result
    if(!success) {
        int error = GetLastError();
        string error_message;
        StringConcatenate(error_message, "Error code: ", error);  // Use StringConcatenate instead
        
        Print("Failed to open sell order: ", error_message);
        Print("Ask: ", ask, " Bid: ", bid, " Lot: ", lot, " SL: ", sl, " TP: ", tp);
        return false;
    }
    
    if(result.retcode == TRADE_RETCODE_DONE) {
        Print("Sell order opened successfully: ", result.order, 
              " Lot: ", lot,
              " Entry: ", bid,
              " SL: ", sl,
              " TP: ", tp);
        return true;
    }
    else {
        Print("Error opening sell order. Return code: ", result.retcode,
              " Comment: ", result.comment);
        return false;
    }
}

// Add this function to determine market session
string DetermineMarketSession() {
    datetime current_time = TimeCurrent();
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    int hour = time_struct.hour;
    
    // Convert to GMT time (adjust based on your broker's timezone)
    hour = (hour + 0) % 24;  // Adjust the +0 based on your broker's GMT offset
    
    if(hour >= 8 && hour < 16) return "London";
    else if(hour >= 13 && hour < 21) return "New York";
    else if(hour >= 0 && hour < 8) return "Tokyo";
    else if(hour >= 2 && hour < 10) return "Sydney";
    else return "Off-Hours";
}

// Add this function to determine market phase
string DetermineMarketPhase() {
    double ma20 = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    double ma50 = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    
    if(current_price > ma20 && ma20 > ma50) return "Uptrend";
    else if(current_price < ma20 && ma20 < ma50) return "Downtrend";
    else if(MathAbs(current_price - ma20) < atr * 0.5) return "Consolidation";
    else return "Choppy";
}

// Add this helper function
string AnalyzeTrendForTimeframe(ENUM_TIMEFRAMES timeframe) {
    double ma20 = iMA(_Symbol, timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);
    double ma50 = iMA(_Symbol, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
    double current_price = iClose(_Symbol, timeframe, 0);
    
    if(current_price > ma20 && ma20 > ma50) return "Uptrend";
    else if(current_price < ma20 && ma20 < ma50) return "Downtrend";
    else return "Sideways";
}

// Calculate RSI for a specific timeframe
double CalculateRSI(ENUM_TIMEFRAMES timeframe) {
    double rsi[];
    ArraySetAsSeries(rsi, true);
    int rsi_handle = iRSI(_Symbol, timeframe, 14, PRICE_CLOSE);
    
    if(rsi_handle == INVALID_HANDLE) return 0;
    
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) <= 0) {
        IndicatorRelease(rsi_handle);
        return 0;
    }
    
    IndicatorRelease(rsi_handle);
    return rsi[0];
}

// Calculate MACD for a specific timeframe
void CalculateMACD(ENUM_TIMEFRAMES timeframe, double &macd_value, double &signal_value) {
    Print("=== MACD Calculation Debug ===");
    Print("Timeframe: ", EnumToString(timeframe));
    
    // Create MACD indicator handle
    int macd_handle = iMACD(_Symbol, timeframe, 12, 26, 9, PRICE_CLOSE);
    if(macd_handle == INVALID_HANDLE) {
        Print("Failed to create MACD indicator handle. Error: ", GetLastError());
        return;
    }
    Print("MACD handle created successfully: ", macd_handle);

    // Initialize arrays
    double macd_buffer[];
    double signal_buffer[];
    ArraySetAsSeries(macd_buffer, true);
    ArraySetAsSeries(signal_buffer, true);
    
    // Allocate enough space for calculation
    ArrayResize(macd_buffer, 100);  // Increased buffer size
    ArrayResize(signal_buffer, 100);

    // Copy MACD values with detailed error checking
    int copied_macd = CopyBuffer(macd_handle, 0, 0, 100, macd_buffer);
    int copied_signal = CopyBuffer(macd_handle, 1, 0, 100, signal_buffer);
    
    Print("MACD buffer copied: ", copied_macd, " values");
    Print("Signal buffer copied: ", copied_signal, " values");
    
    if(copied_macd <= 0 || copied_signal <= 0) {
        Print("Failed to copy MACD buffers. Error: ", GetLastError());
        Print("MACD copy result: ", copied_macd);
        Print("Signal copy result: ", copied_signal);
        macd_value = 0;
        signal_value = 0;
    } else {
        // Print first few values for debugging
        Print("First 3 MACD values: ", 
              DoubleToString(macd_buffer[0], 8), ", ",
              DoubleToString(macd_buffer[1], 8), ", ",
              DoubleToString(macd_buffer[2], 8));
        Print("First 3 Signal values: ", 
              DoubleToString(signal_buffer[0], 8), ", ",
              DoubleToString(signal_buffer[1], 8), ", ",
              DoubleToString(signal_buffer[2], 8));
              
        macd_value = NormalizeDouble(macd_buffer[0], 8);
        signal_value = NormalizeDouble(signal_buffer[0], 8);
        
        // Convert to pips for display
        double macd_pips = macd_value * 10000;
        double signal_pips = signal_value * 10000;
        Print("MACD in pips: ", DoubleToString(macd_pips, 2));
        Print("Signal in pips: ", DoubleToString(signal_pips, 2));
    }

    Print("Final MACD value: ", DoubleToString(macd_value, 8));
    Print("Final Signal value: ", DoubleToString(signal_value, 8));
    Print("=== End MACD Debug ===");

    IndicatorRelease(macd_handle);
}

// Calculate volatility for a specific period
double CalculateVolatility(ENUM_TIMEFRAMES timeframe, int periods) {
    double closes[];
    ArraySetAsSeries(closes, true);
    
    if(CopyClose(_Symbol, timeframe, 0, periods + 1, closes) <= 0) 
        return 0;
    
    double sum = 0;
    for(int i = 0; i < periods; i++) {
        double daily_return = (closes[i] - closes[i + 1]) / closes[i + 1] * 100;
        sum += MathPow(daily_return, 2);
    }
    
    return MathSqrt(sum / periods) * MathSqrt(252); // Annualized volatility
}

// Calculate volume metrics
void CalculateVolumeMetrics(MarketData &data) {
    long volume[];
    ArraySetAsSeries(volume, true);
    
    if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, VOLUME_MA_PERIOD, volume) <= 0)
        return;
        
    double sum = 0.0;
    for(int i = 0; i < VOLUME_MA_PERIOD; i++) {
        // Use intermediate variable for explicit conversion
        long current_volume = volume[i];
        sum += (double)current_volume;
    }
        
    data.volume_ma = sum / VOLUME_MA_PERIOD;
    
    // Use intermediate variable for explicit conversion
    long prev_volume = volume[1];
    data.prev_day_volume = (double)prev_volume;
}

//+------------------------------------------------------------------+
//| Detect patterns for a specific timeframe                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect patterns for a specific timeframe                          |
//+------------------------------------------------------------------+
void DetectPatternsForTimeframe(ENUM_TIMEFRAMES timeframe, string &patterns[]) {
    const int lookback = 500;
    double highs[], lows[], closes[], opens[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(closes, true);
    ArraySetAsSeries(opens, true);
    
    if(CopyHigh(_Symbol, timeframe, 0, lookback, highs) <= 0 ||
       CopyLow(_Symbol, timeframe, 0, lookback, lows) <= 0 ||
       CopyClose(_Symbol, timeframe, 0, lookback, closes) <= 0 ||
       CopyOpen(_Symbol, timeframe, 0, lookback, opens) <= 0) {
        return;
    }
    
    ArrayResize(patterns, 0);
    
    // Technical Patterns
    // Check for double top
    if(DetectDoubleTop(highs, lows, closes)) {
        ArrayResize(patterns, ArraySize(patterns) + 1);
        patterns[ArraySize(patterns) - 1] = "Double Top";
    }
    
    // Check for double bottom
    if(DetectDoubleBottom(highs, lows, closes)) {
        ArrayResize(patterns, ArraySize(patterns) + 1);
        patterns[ArraySize(patterns) - 1] = "Double Bottom";
    }
    
    // Check for head and shoulders
    if(DetectInverseHeadAndShoulders(highs, lows, closes, timeframe)) {
        ArrayResize(patterns, ArraySize(patterns) + 1);
        patterns[ArraySize(patterns) - 1] = "Inverse Head and Shoulders";
    }
    
    // Japanese Candlestick Patterns
    for(int i = 0; i < lookback - 3; i++) {
        // Single Candlestick Patterns
        double body = MathAbs(closes[i] - opens[i]);
        double upper_shadow = highs[i] - MathMax(opens[i], closes[i]);
        double lower_shadow = MathMin(opens[i], closes[i]) - lows[i];
        double total_range = highs[i] - lows[i];
        
        // Doji Patterns
        if(body < total_range * 0.1) {
            if(upper_shadow > lower_shadow * 3) {
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Gravestone Doji";
            }
            else if(lower_shadow > upper_shadow * 3) {
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Dragonfly Doji";
            }
            else {
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Doji";
            }
        }
        
        // Hammer/Hanging Man
        if(lower_shadow > body * 2 && upper_shadow < body * 0.5) {
            ArrayResize(patterns, ArraySize(patterns) + 1);
            patterns[ArraySize(patterns) - 1] = closes[i] > opens[i] ? "Hammer" : "Hanging Man";
        }
        
        // Shooting Star/Inverted Hammer
        if(upper_shadow > body * 2 && lower_shadow < body * 0.5) {
            ArrayResize(patterns, ArraySize(patterns) + 1);
            patterns[ArraySize(patterns) - 1] = closes[i] < opens[i] ? "Shooting Star" : "Inverted Hammer";
        }
        
        // Marubozu (Strong trend candles)
        if(body > total_range * 0.9) {
            ArrayResize(patterns, ArraySize(patterns) + 1);
            patterns[ArraySize(patterns) - 1] = closes[i] > opens[i] ? "Bullish Marubozu" : "Bearish Marubozu";
        }
        
        // Two Candlestick Patterns
        if(i < lookback - 2) {
            // Engulfing Patterns
            if(body > MathAbs(closes[i+1] - opens[i+1])) {
                if(closes[i] > opens[i] && closes[i+1] < opens[i+1] &&
                   opens[i] < closes[i+1] && closes[i] > opens[i+1]) {
                    ArrayResize(patterns, ArraySize(patterns) + 1);
                    patterns[ArraySize(patterns) - 1] = "Bullish Engulfing";
                }
                else if(closes[i] < opens[i] && closes[i+1] > opens[i+1] &&
                        opens[i] > closes[i+1] && closes[i] < opens[i+1]) {
                    ArrayResize(patterns, ArraySize(patterns) + 1);
                    patterns[ArraySize(patterns) - 1] = "Bearish Engulfing";
                }
            }
            
            // Harami Patterns
            if(body < MathAbs(closes[i+1] - opens[i+1]) * 0.5) {
                if(closes[i+1] < opens[i+1] && closes[i] > opens[i] &&
                   opens[i] > closes[i+1] && closes[i] < opens[i+1]) {
                    ArrayResize(patterns, ArraySize(patterns) + 1);
                    patterns[ArraySize(patterns) - 1] = "Bullish Harami";
                }
                else if(closes[i+1] > opens[i+1] && closes[i] < opens[i] &&
                        opens[i] < closes[i+1] && closes[i] > opens[i+1]) {
                    ArrayResize(patterns, ArraySize(patterns) + 1);
                    patterns[ArraySize(patterns) - 1] = "Bearish Harami";
                }
            }
            
            // Tweezer Patterns
            if(MathAbs(highs[i] - highs[i+1]) < Point() * 3 &&
               MathAbs(lows[i] - lows[i+1]) < Point() * 3) {
                if(closes[i] > opens[i] && closes[i+1] < opens[i+1]) {
                    ArrayResize(patterns, ArraySize(patterns) + 1);
                    patterns[ArraySize(patterns) - 1] = "Tweezer Bottom";
                }
                else if(closes[i] < opens[i] && closes[i+1] > opens[i+1]) {
                    ArrayResize(patterns, ArraySize(patterns) + 1);
                    patterns[ArraySize(patterns) - 1] = "Tweezer Top";
                }
            }
        }
        
        // Three Candlestick Patterns
        if(i < lookback - 3) {
            // Morning Star
            if(closes[i+2] < opens[i+2] &&                           // First candle bearish
               MathAbs(closes[i+1] - opens[i+1]) < body * 0.3 &&    // Small middle candle
               closes[i] > opens[i] &&                               // Third candle bullish
               closes[i] > (opens[i+2] + closes[i+2]) / 2) {        // Closed above midpoint of first candle
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Morning Star";
            }
            
            // Evening Star
            if(closes[i+2] > opens[i+2] &&                           // First candle bullish
               MathAbs(closes[i+1] - opens[i+1]) < body * 0.3 &&    // Small middle candle
               closes[i] < opens[i] &&                               // Third candle bearish
               closes[i] < (opens[i+2] + closes[i+2]) / 2) {        // Closed below midpoint of first candle
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Evening Star";
            }
            
            // Three White Soldiers
            if(closes[i] > opens[i] && closes[i+1] > opens[i+1] && closes[i+2] > opens[i+2] &&
               opens[i] > opens[i+1] && opens[i+1] > opens[i+2] &&
               closes[i] > closes[i+1] && closes[i+1] > closes[i+2]) {
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Three White Soldiers";
            }
            
            // Three Black Crows
            if(closes[i] < opens[i] && closes[i+1] < opens[i+1] && closes[i+2] < opens[i+2] &&
               opens[i] < opens[i+1] && opens[i+1] < opens[i+2] &&
               closes[i] < closes[i+1] && closes[i+1] < closes[i+2]) {
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Three Black Crows";
            }
            
            // Three Inside Up
            if(closes[i+2] < opens[i+2] &&                          // First candle bearish
               opens[i+1] < closes[i+2] && closes[i+1] > opens[i+2] && // Second inside first
               closes[i] > opens[i] && closes[i] > closes[i+1]) {    // Third bullish above second
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Three Inside Up";
            }
            
            // Three Inside Down
            if(closes[i+2] > opens[i+2] &&                          // First candle bullish
               opens[i+1] > closes[i+2] && closes[i+1] < opens[i+2] && // Second inside first
               closes[i] < opens[i] && closes[i] < closes[i+1]) {    // Third bearish below second
                ArrayResize(patterns, ArraySize(patterns) + 1);
                patterns[ArraySize(patterns) - 1] = "Three Inside Down";
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate pivot points for last 3 days                            |
//+------------------------------------------------------------------+
void CalculatePivotPoints(int day_index, MarketData::PivotPoints &pivot) {
    double high = iHigh(_Symbol, PERIOD_D1, day_index);
    double low = iLow(_Symbol, PERIOD_D1, day_index);
    double close = iClose(_Symbol, PERIOD_D1, day_index);
    
    // Calculate pivot point
    pivot.pp = (high + low + close) / 3;
    
    // Calculate support and resistance levels
    pivot.r1 = (2 * pivot.pp) - low;
    pivot.r2 = pivot.pp + (high - low);
    pivot.r3 = high + 2 * (pivot.pp - low);
    
    pivot.s1 = (2 * pivot.pp) - high;
    pivot.s2 = pivot.pp - (high - low);
    pivot.s3 = low - 2 * (high - pivot.pp);
}

// When calculating volatilities
void UpdateVolatilityMetrics(MarketData &data) {
    data.daily_volatility = CalculateVolatility(PERIOD_D1, 1);
    data.weekly_volatility = CalculateVolatility(PERIOD_D1, 5);
    data.monthly_volatility = CalculateVolatility(PERIOD_D1, 20);
}

//+------------------------------------------------------------------+
//| Check if the signal's risk level is allowed by user settings      |
//+------------------------------------------------------------------+
bool IsRiskLevelAllowed(const string risk_level) {
    // Convert signal risk string to comparable level
    int signal_level = 
        StringCompare(risk_level, "LOW") == 0 ? 0 :
        StringCompare(risk_level, "MEDIUM") == 0 ? 1 :
        StringCompare(risk_level, "HIGH") == 0 ? 2 : -1;
    
    // Invalid risk level in signal
    if(signal_level == -1) {
        Print("Invalid risk level received: ", risk_level);
        return false;
    }
    
    // Check if signal risk level is allowed by user preference
    switch(InpRiskLevel) {
        case RISK_LOW:
            return signal_level == 0;  // Only allow LOW risk signals
        
        case RISK_MEDIUM:
            return signal_level <= 1;  // Allow LOW and MEDIUM risk signals
        
        case RISK_HIGH:
            return true;  // Allow all risk levels
        
        default:
            Print("Invalid risk level setting");
            return false;
    }
}

//+------------------------------------------------------------------+
//| Take and save chart screenshots for multiple timeframes            |
//+------------------------------------------------------------------+
string TakeChartScreenshot() {
return true;
    // Save current timeframe
    ENUM_TIMEFRAMES original_timeframe = (ENUM_TIMEFRAMES)ChartPeriod(0);
    string screenshots = "";
    
    // Array of timeframes to capture
    ENUM_TIMEFRAMES timeframes[] = {PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_D1};
    
    // Take screenshots for each timeframe
    for(int i = 0; i < ArraySize(timeframes); i++) {
        // Change chart timeframe
        if(!ChartSetSymbolPeriod(0, _Symbol, timeframes[i])) {
            Print("Failed to change timeframe to ", EnumToString(timeframes[i]));
            continue;
        }
        
        // Allow chart to update
        ChartRedraw();
        Sleep(1000);  // Wait for chart to update
        
        // Create filename with account info and timeframe
        string filename = StringFormat("%lld_%s_%s.png", 
            AccountInfoInteger(ACCOUNT_LOGIN),
            AccountInfoString(ACCOUNT_SERVER),
            EnumToString(timeframes[i])
        );
        
        StringReplace(filename, ":", "-");
        
        // Set chart properties for screenshot
        ChartSetInteger(ChartID(), CHART_BRING_TO_TOP, true);
        ChartSetInteger(ChartID(), CHART_SHOW_GRID, false);
        ChartSetInteger(ChartID(), CHART_MODE, CHART_CANDLES);
        ChartSetInteger(ChartID(), CHART_SCALE, 5);  // Adjust scale to show more candles
        ChartNavigate(ChartID(), CHART_END, 0);      // Scroll to the latest candles
        
        // Get chart dimensions
        int chart_width = (int)ChartGetInteger(ChartID(), CHART_WIDTH_IN_PIXELS);
        int chart_height = (int)ChartGetInteger(ChartID(), CHART_HEIGHT_IN_PIXELS);
        
        // Ensure minimum dimensions
        chart_width = MathMax(chart_width, 1024);
        chart_height = MathMax(chart_height, 768);
        
        // Take screenshot
        if(!ChartScreenShot(ChartID(), filename, chart_width, chart_height, ALIGN_RIGHT)) {
            int error = GetLastError();
            Print("Failed to take screenshot for ", EnumToString(timeframes[i]), 
                  ". Error code: ", error,
                  ". Error description: ", ErrorDescription(error));
            continue;
        }
        
        // Get the full path for the saved file
        string terminal_path = TerminalInfoString(TERMINAL_DATA_PATH);
        string full_path = terminal_path + "\\MQL5\\Files\\" + filename;
        
        Print("Screenshot saved for ", EnumToString(timeframes[i]), ": ", full_path);
        screenshots += full_path + ";";  // Concatenate paths with separator
    }
    
    // Restore original timeframe
    if(!ChartSetSymbolPeriod(0, _Symbol, original_timeframe)) {
        Print("Failed to restore original timeframe ", EnumToString(original_timeframe));
    }
    
    ChartRedraw();
    return screenshots;  // Return all screenshot paths
}


//+------------------------------------------------------------------+
//| Helper function to check if directory exists                       |
//+------------------------------------------------------------------+
bool DirectoryExists(string path) {
    if(FileIsExist(path)) return true;
    
    Print("Attempting to create directory: ", path);
    bool result = FolderCreate(path);
    if(!result) {
        int error = GetLastError();
        Print("FolderCreate failed. Error code: ", error);
        Print("Error description: ", ErrorDescription(error));
    }
    return result;
}

//+------------------------------------------------------------------+
//| Helper function to get error description                          |
//+------------------------------------------------------------------+
string ErrorDescription(int error_code) {
    switch(error_code) {
        case ERR_NOT_ENOUGH_MEMORY: return "Not enough memory";
        case ERR_WRONG_FILENAME: return "Invalid filename";
        case ERR_TOO_LONG_FILENAME: return "Filename too long";
        case ERR_CANNOT_OPEN_FILE: return "Cannot open file";
        case ERR_FILE_WRITEERROR: return "File write error";
        case ERR_DIRECTORY_NOT_EXIST: return "Directory does not exist";
        default: return "Unknown error";
    }
}

//+------------------------------------------------------------------+
//| Structure for trend analysis result                                |
//+------------------------------------------------------------------+
struct TrendAnalysisResult {
    bool isReversing;           // True if trend appears to be reversing
    string direction;           // "UP", "DOWN", or "SIDEWAYS"
    double reversalStrength;    // 0-100 indicating strength of reversal signal
    string reason;             // Explanation for the reversal signal
    double suggestedExitPrice; // Suggested price to exit the trade
};

//+------------------------------------------------------------------+
//| Smart trade monitoring function                                    |
//+------------------------------------------------------------------+
void MonitorActiveTrades() {
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionSelectByTicket(PositionGetTicket(i))) {
            // Skip if not our symbol
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            
            // Get position details
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double stopLoss = PositionGetDouble(POSITION_SL);
            double takeProfit = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            // Check if profit is >= $10 and stop loss isn't at entry price yet
            if(profit >= 10.0 && MathAbs(stopLoss - openPrice) > 0.0001) {
                // Prepare trade request to modify stop loss
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                
                request.action = TRADE_ACTION_SLTP;
                request.position = PositionGetTicket(i);
                request.symbol = _Symbol;
                request.sl = openPrice;  // Move stop loss to entry price
                request.tp = takeProfit; // Keep existing take profit
                
                // Send the modification request
                bool success = OrderSend(request, result);
                if(success) {
                    Print("Modified stop loss to break-even at ", openPrice, " for position ", request.position);
                } else {
                    Print("Failed to modify stop loss. Error: ", GetLastError());
                }
            }
            
            // Analyze current trend
            TrendAnalysisResult analysis = AnalyzeReversalSignals(posType);
            
            // If we have profit and trend is reversing, consider closing
            if(profit > 0 && analysis.isReversing) {
                bool shouldClose = false;
                string closeReason = "";
                
                // Calculate risk metrics
                double riskToReward = CalculateRiskToReward(currentPrice, stopLoss, takeProfit);
                double profitPercent = (profit / AccountInfoDouble(ACCOUNT_BALANCE)) * 100;
                
                // Decision logic for closing trade
                if(analysis.reversalStrength >= 80 && profitPercent >= 0.5) {
                    shouldClose = true;
                    closeReason = "Strong reversal signal (" + DoubleToString(analysis.reversalStrength, 1) + 
                                "%) with " + DoubleToString(profitPercent, 2) + "% profit";
                }
                else if(analysis.reversalStrength >= 60 && riskToReward < 1) {
                    shouldClose = true;
                    closeReason = "Moderate reversal with unfavorable risk/reward";
                }
                else if(profitPercent >= 1.0 && analysis.reversalStrength >= 50) {
                    shouldClose = true;
                    closeReason = "Good profit with potential reversal";
                }
                
                // Close the trade if conditions are met
                if(shouldClose) {
                    if(ClosePosition(PositionGetTicket(i), closeReason)) {
                        Print("Trade closed due to reversal signal: ", closeReason);
                        Print("Analysis details: ", analysis.reason);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyze potential trend reversal signals                           |
//+------------------------------------------------------------------+
TrendAnalysisResult AnalyzeReversalSignals(ENUM_POSITION_TYPE posType) {
    TrendAnalysisResult result = {false, "", 0, "", 0};
    string reasons[];
    int reasonCount = 0;
    double totalStrength = 0;
    
    // Get indicator values
    double rsi = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    double macd[], signal[];
    ArraySetAsSeries(macd, true);
    ArraySetAsSeries(signal, true);
    int macdHandle = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
    CopyBuffer(macdHandle, 0, 0, 2, macd);
    CopyBuffer(macdHandle, 1, 0, 2, signal);
    
    // Get multiple timeframe MA crosses
    bool ma_cross_m15 = CheckMACross(PERIOD_M15);
    bool ma_cross_h1 = CheckMACross(PERIOD_H1);
    bool ma_cross_h4 = CheckMACross(PERIOD_H4);
    
    // Check RSI extremes
    if(posType == POSITION_TYPE_BUY && rsi > 70) {
        ArrayResize(reasons, reasonCount + 1);
        reasons[reasonCount++] = "RSI overbought (" + DoubleToString(rsi, 1) + ")";
        totalStrength += 20;
    }
    else if(posType == POSITION_TYPE_SELL && rsi < 30) {
        ArrayResize(reasons, reasonCount + 1);
        reasons[reasonCount++] = "RSI oversold (" + DoubleToString(rsi, 1) + ")";
        totalStrength += 20;
    }
    
    // Check MACD crossover
    if(posType == POSITION_TYPE_BUY && macd[0] < signal[0] && macd[1] > signal[1]) {
        ArrayResize(reasons, reasonCount + 1);
        reasons[reasonCount++] = "MACD bearish crossover";
        totalStrength += 15;
    }
    else if(posType == POSITION_TYPE_SELL && macd[0] > signal[0] && macd[1] < signal[1]) {
        ArrayResize(reasons, reasonCount + 1);
        reasons[reasonCount++] = "MACD bullish crossover";
        totalStrength += 15;
    }
    
    // Check MA crosses on multiple timeframes
    if(posType == POSITION_TYPE_BUY) {
        if(ma_cross_m15) totalStrength += 10;
        if(ma_cross_h1) totalStrength += 15;
        if(ma_cross_h4) totalStrength += 20;
        
        if(ma_cross_h4) {
            ArrayResize(reasons, reasonCount + 1);
            reasons[reasonCount++] = "Bearish MA cross on H4";
        }
    }
    else if(posType == POSITION_TYPE_SELL) {
        if(ma_cross_m15) totalStrength += 10;
        if(ma_cross_h1) totalStrength += 15;
        if(ma_cross_h4) totalStrength += 20;
        
        if(ma_cross_h4) {
            ArrayResize(reasons, reasonCount + 1);
            reasons[reasonCount++] = "Bullish MA cross on H4";
        }
    }
    
    // Check volume
    long volume[];
    ArraySetAsSeries(volume, true);
    CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 3, volume);
    if(volume[0] > volume[1] * 1.5) {
        ArrayResize(reasons, reasonCount + 1);
        reasons[reasonCount++] = "Significant volume increase";
        totalStrength += 10;
    }
    
    // Compile final result
    result.isReversing = totalStrength >= 50;
    result.reversalStrength = MathMin(totalStrength, 100);
    result.direction = posType == POSITION_TYPE_BUY ? "DOWN" : "UP";
    
    // Combine all reasons
    string allReasons = "";
    for(int i = 0; i < reasonCount; i++) {
        if(i > 0) allReasons += "; ";
        allReasons += reasons[i];
    }
    result.reason = allReasons;
    
    return result;
}

//+------------------------------------------------------------------+
//| Check for MA cross on specified timeframe                          |
//+------------------------------------------------------------------+
bool CheckMACross(ENUM_TIMEFRAMES timeframe) {
    double ma20[], ma50[];
    ArraySetAsSeries(ma20, true);
    ArraySetAsSeries(ma50, true);
    
    int ma20Handle = iMA(_Symbol, timeframe, 20, 0, MODE_SMA, PRICE_CLOSE);
    int ma50Handle = iMA(_Symbol, timeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
    
    CopyBuffer(ma20Handle, 0, 0, 2, ma20);
    CopyBuffer(ma50Handle, 0, 0, 2, ma50);
    
    bool crossDown = ma20[1] > ma50[1] && ma20[0] < ma50[0];
    bool crossUp = ma20[1] < ma50[1] && ma20[0] > ma50[0];
    
    IndicatorRelease(ma20Handle);
    IndicatorRelease(ma50Handle);
    
    return crossDown || crossUp;
}

//+------------------------------------------------------------------+
//| Calculate current risk to reward ratio                             |
//+------------------------------------------------------------------+
double CalculateRiskToReward(double currentPrice, double stopLoss, double takeProfit) {
    if(MathAbs(currentPrice - stopLoss) < 0.0000001) return 0;
    return MathAbs(takeProfit - currentPrice) / MathAbs(currentPrice - stopLoss);
}

//+------------------------------------------------------------------+
//| Close position with logging                                        |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, string reason) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.deviation = 5;
    request.magic = 123456;
    request.comment = "Smart close: " + reason;
    
    // Set order type opposite to position type
    request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                  ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    
    request.price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ?
                   SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    bool success = OrderSend(request, result);
    
    if(success) {
        Print("Position ", ticket, " closed successfully. Reason: ", reason);
    } else {
        Print("Failed to close position ", ticket, ". Error: ", GetLastError());
    }
    
    return success;
}
//+------------------------------------------------------------------+
//| CheckLocalTradeSignals with Confluence Scoring                   |
//+------------------------------------------------------------------+
void CheckLocalTradeSignals() 
{
    // --------------------------------------------------
    // 1. Check if we can open a new position
    // --------------------------------------------------
    if(totalActiveTrades >= InpMaxActiveTrades) return;

    // --------------------------------------------------
    // 2. Create scoring variables
    // --------------------------------------------------
    double bullishScore = 0.0;
    double bearishScore = 0.0;

    // --------------------------------------------------
    // 3. Evaluate multi-timeframe trend
    // --------------------------------------------------
    string trendM15 = AnalyzeTimeframe(PERIOD_M15);
    string trendH1  = AnalyzeTimeframe(PERIOD_H1);
    string trendH4  = AnalyzeTimeframe(PERIOD_H4);

    // -- Weighted approach for multi-timeframe:
    //    Each uptrend adds +1, each downtrend adds -1
    //    "Sideways" adds 0
    bullishScore += (trendM15 == "Uptrend")   ? 1.0 : 0;
    bullishScore += (trendH1  == "Uptrend")   ? 1.0 : 0;
    bullishScore += (trendH4  == "Uptrend")   ? 1.0 : 0;

    bearishScore += (trendM15 == "Downtrend") ? 1.0 : 0;
    bearishScore += (trendH1  == "Downtrend") ? 1.0 : 0;
    bearishScore += (trendH4  == "Downtrend") ? 1.0 : 0;

    // --------------------------------------------------
    // 4. RSI check
    // --------------------------------------------------
    MarketData data;
    double rsi = data.rsi;
    if(rsi < 30)  bullishScore += 1.0;    // oversold → bullish possibility
    if(rsi > 70)  bearishScore += 1.0;    // overbought → bearish possibility

    // --------------------------------------------------
    // 5. MACD check
    // --------------------------------------------------
    double macdVal[2], signalVal[2];
    ArraySetAsSeries(macdVal,   true);
    ArraySetAsSeries(signalVal, true);

    int macdHandle = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
    if(macdHandle != INVALID_HANDLE) {
        CopyBuffer(macdHandle, 0, 0, 2, macdVal);    // MACD line
        CopyBuffer(macdHandle, 1, 0, 2, signalVal);  // Signal line
        IndicatorRelease(macdHandle);
    }

    // Bullish MACD
    if(macdVal[0] > signalVal[0] && macdVal[0] > 0) {
        bullishScore += 1.0;
    }
    // Bearish MACD
    if(macdVal[0] < signalVal[0] && macdVal[0] < 0) {
        bearishScore += 1.0;
    }

    // --------------------------------------------------
    // 6. ADX Check
    // --------------------------------------------------
    double adxVal[], plusDI[], minusDI[];
    ArraySetAsSeries(adxVal, true);
    ArraySetAsSeries(plusDI, true);
    ArraySetAsSeries(minusDI, true);

    // Correct ADX handle creation with 14 period
    int adxHandle = iADX(_Symbol, PERIOD_CURRENT, 14);
    
    // We don't need separate handles for +DI and -DI as they are included in ADX indicator buffers
    if(adxHandle != INVALID_HANDLE)
    {
        // ADX main value is buffer 0
        // +DI is buffer 1
        // -DI is buffer 2
        CopyBuffer(adxHandle, 0, 0, 1, adxVal);    // Main ADX line
        CopyBuffer(adxHandle, 1, 0, 1, plusDI);    // +DI line
        CopyBuffer(adxHandle, 2, 0, 1, minusDI);   // -DI line

        IndicatorRelease(adxHandle);

        // If ADX is above a threshold, we add a stronger weighting
        if(adxVal[0] >= 25.0)
        {
            if(plusDI[0] > minusDI[0]) {
                bullishScore += 1.0; // strong bullish trend
            }
            else if(minusDI[0] > plusDI[0]) {
                bearishScore += 1.0; // strong bearish trend
            }
        }
    }

    // --------------------------------------------------
    // 7. Optional: Stochastic or Bollinger 
    // --------------------------------------------------
    // For demonstration, we omit detailed code here; 
    // just remember each check adds or subtracts from 
    // bullishScore or bearishScore.

    // --------------------------------------------------
    // 8. Decide on trades based on the final scores
    // --------------------------------------------------
    // For instance, if bullishScore >= 3, open a buy
    // If bearishScore >= 3, open a sell
    // (Tune these thresholds to your preference)
    int threshold = 3;

    if(bullishScore >= threshold && bullishScore > bearishScore) {
        // Enough bullish confluence to open a BUY
        double sl = CalculateStopLoss("BUY");
        double tp = CalculateTakeProfit("BUY");
        OpenBuyOrder(InpLotSize, sl, tp);
        Print("Confluence Score: Opening BUY (Score=", bullishScore, ")");
    }
    else if(bearishScore >= threshold && bearishScore > bullishScore) {
        // Enough bearish confluence to open a SELL
        double sl = CalculateStopLoss("SELL");
        double tp = CalculateTakeProfit("SELL");
        OpenSellOrder(InpLotSize, sl, tp);
        Print("Confluence Score: Opening SELL (Score=", bearishScore, ")");
    }
    else {
        // Scores do not justify a trade
        Print("Confluence Score: No trade. Bullish=", bullishScore, 
              " Bearish=", bearishScore);
    }
}

//+------------------------------------------------------------------+
//| Calculate StopLoss & TakeProfit (unchanged)                      |
//+------------------------------------------------------------------+
double CalculateStopLoss(string direction) {
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if(direction == "BUY") {
        return currentPrice - (atr * 1.5);
    } else {
        return currentPrice + (atr * 1.5);
    }
}

double CalculateTakeProfit(string direction) {
    double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if(direction == "BUY") {
        return currentPrice + (atr * 3.0);
    } else {
        return currentPrice - (atr * 3.0);
    }
}

//+------------------------------------------------------------------+
//| Trend Analysis for timeframe (unchanged)                         |
//+------------------------------------------------------------------+
string AnalyzeTimeframe(ENUM_TIMEFRAMES timeframe) {
    double ma20[], ma50[], ma200[];
    ArraySetAsSeries(ma20,  true);
    ArraySetAsSeries(ma50,  true);
    ArraySetAsSeries(ma200, true);

    int ma20_handle  = iMA(_Symbol, timeframe, 20,  0, MODE_SMA, PRICE_CLOSE);
    int ma50_handle  = iMA(_Symbol, timeframe, 50,  0, MODE_SMA, PRICE_CLOSE);
    int ma200_handle = iMA(_Symbol, timeframe, 200, 0, MODE_SMA, PRICE_CLOSE);

    if(ma20_handle == INVALID_HANDLE || 
       ma50_handle == INVALID_HANDLE || 
       ma200_handle == INVALID_HANDLE) 
    {
        Print("Failed to create MA handles");
        return "Error";
    }

    if(CopyBuffer(ma20_handle,  0, 0, 2, ma20)  <= 0 ||
       CopyBuffer(ma50_handle,  0, 0, 2, ma50)  <= 0 ||
       CopyBuffer(ma200_handle, 0, 0, 2, ma200) <= 0)
    {
        Print("Failed to copy MA values");
        return "Error";
    }

    IndicatorRelease(ma20_handle);
    IndicatorRelease(ma50_handle);
    IndicatorRelease(ma200_handle);

    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Determine Uptrend / Downtrend / Sideways
    if(current_price > ma20[0] && ma20[0] > ma50[0] && ma50[0] > ma200[0]) {
        return "Uptrend";
    }
    else if(current_price < ma20[0] && ma20[0] < ma50[0] && ma50[0] < ma200[0]) {
        return "Downtrend";
    }
    else {
        return "Sideways";
    }
}


string PrepareTimeframeHistory(ENUM_TIMEFRAMES timeframe, int bars_to_include) {
    // Calculate indicators
    double rsi_value = CalculateRSI(timeframe);
    
    double macd_value, signal_value;
    CalculateMACD(timeframe, macd_value, signal_value);
    double macd_pips = macd_value * 10000;
    double signal_pips = signal_value * 10000;
    
    double di_plus, di_minus;
    double adx = CalculateADX(timeframe, di_plus, di_minus);
    
    string history = StringFormat(
        "Time: %s | %s | O: %.5f H: %.5f L: %.5f C: %.5f | %s | Body: %.1f%% | "
        "Shadows U:%.1f%% L:%.1f%% | Vol: %.2f | MA(20,50,200)=(%.5f,%.5f,%.5f) | "
        "RSI=%.2f, MACD=(%.2f,%.2f), ADX=(%.2f,%.2f,%.2f), ",
        TimeToString(iTime(_Symbol, timeframe, 0)),
        // ... other parameters ...
        rsi_value,
        macd_pips,
        signal_pips,
        adx,        // Main ADX value
        di_plus,    // DI+ value
        di_minus    // DI- value
    );

    return history;
}

//+------------------------------------------------------------------+
//| Calculate ADX indicator values                                     |
//+------------------------------------------------------------------+
double CalculateADX(ENUM_TIMEFRAMES timeframe, double &di_plus, double &di_minus) {
    double adx_buffer[], plus_buffer[], minus_buffer[];
    ArraySetAsSeries(adx_buffer, true);
    ArraySetAsSeries(plus_buffer, true);
    ArraySetAsSeries(minus_buffer, true);
    
    // Create ADX indicator handle with standard 14-period setting
    int adx_handle = iADX(_Symbol, timeframe, 14);
    if(adx_handle == INVALID_HANDLE) {
        Print("Failed to create ADX indicator handle. Error: ", GetLastError());
        return 0;
    }

    // Copy ADX values
    if(CopyBuffer(adx_handle, 0, 0, 1, adx_buffer) <= 0 ||    // Main ADX line
       CopyBuffer(adx_handle, 1, 0, 1, plus_buffer) <= 0 ||   // +DI line
       CopyBuffer(adx_handle, 2, 0, 1, minus_buffer) <= 0) {  // -DI line
        Print("Failed to copy ADX buffers. Error: ", GetLastError());
        IndicatorRelease(adx_handle);
        return 0;
    }

    // Store DI+ and DI- values
    di_plus = NormalizeDouble(plus_buffer[0], 2);
    di_minus = NormalizeDouble(minus_buffer[0], 2);
    
    // Release the indicator handle
    IndicatorRelease(adx_handle);
    
    // Return the main ADX value
    return NormalizeDouble(adx_buffer[0], 2);
}

 

//+------------------------------------------------------------------+
//| Check if market volatility is too high                             |
//+------------------------------------------------------------------+
bool IsMarketTooVolatile(const int bands_handle, const string symbol, const ENUM_TIMEFRAMES timeframe) {
    if(bands_handle == INVALID_HANDLE) return false;
    
    // Initialize arrays with specific size
    double upper[], middle[], lower[];
    ArrayResize(upper, 3);
    ArrayResize(middle, 3);
    ArrayResize(lower, 3);
    ArraySetAsSeries(upper, true);
    ArraySetAsSeries(middle, true);
    ArraySetAsSeries(lower, true);
    
    // Copy Bollinger Bands values with explicit error checking
    int copied = CopyBuffer(bands_handle, 1, 0, 3, upper);
    if(copied <= 0) {
        Print("Failed to copy upper band data: ", GetLastError());
        return false;
    }
    
    copied = CopyBuffer(bands_handle, 0, 0, 3, middle);
    if(copied <= 0) {
        Print("Failed to copy middle band data: ", GetLastError());
        return false;
    }
    
    copied = CopyBuffer(bands_handle, 2, 0, 3, lower);
    if(copied <= 0) {
        Print("Failed to copy lower band data: ", GetLastError());
        return false;
    }
    
    // Calculate Bollinger Band width with safety check
    if(middle[0] == 0) return false;  // Avoid division by zero
    double bandWidth = (upper[0] - lower[0]) / middle[0];
    
    // Initialize and copy price data
    double close[];
    ArrayResize(close, 3);
    ArraySetAsSeries(close, true);
    
    copied = CopyClose(symbol, timeframe, 0, 3, close);
    if(copied <= 0) {
        Print("Failed to copy price data: ", GetLastError());
        return false;
    }
    
    // Calculate recent price volatility with safety check
    if(close[2] == 0) return false;  // Avoid division by zero
    double priceChange = MathAbs((close[0] - close[2]) / close[2]) * 100;
    
    // Market is considered too volatile if:
    // 1. Band width is more than 2% of price
    // 2. Price changed more than 0.5% in last 3 candles
    return (bandWidth > 0.02 || priceChange > 0.5);
}

//+------------------------------------------------------------------+
//| Draw trading signal on chart                                       |
//+------------------------------------------------------------------+
void DrawSignal(string signal, int confidence, double price, datetime time) {
    static int signal_counter = 0;
    signal_counter++;
    
    // Create unique names for the objects
    string signal_name = OBJ_PREFIX_SIGNAL + IntegerToString(signal_counter);
    string conf_name = OBJ_PREFIX_CONF + IntegerToString(signal_counter);
    
    // Delete old objects if they exist
    ObjectDelete(0, signal_name);
    ObjectDelete(0, conf_name);
    
    // Set arrow code and color based on signal
    int arrow_code;
    color arrow_color;
    double arrow_price;
    
    if(signal == "BUY") {
        arrow_code = 233;  // Up arrow symbol
        arrow_color = ARROW_COLOR_BUY;
        // Place arrow below the low price with offset
        arrow_price = iLow(_Symbol, PERIOD_CURRENT, 0) - (60 * Point());
    }
    else if(signal == "SELL") {
        arrow_code = 234;  // Down arrow symbol
        arrow_color = ARROW_COLOR_SELL;
        // Place arrow above the high price with offset
        arrow_price = iHigh(_Symbol, PERIOD_CURRENT, 0) + (60 * Point());
    }
    else {  // HOLD
        arrow_code = 251;  // Circle symbol
        arrow_color = ARROW_COLOR_HOLD;
        arrow_price = iClose(_Symbol, PERIOD_CURRENT, 0);
    }
    
    // Create the arrow
    if(!ObjectCreate(0, signal_name, OBJ_ARROW, 0, time, arrow_price)) {
        Print("Failed to create arrow object! Error: ", GetLastError());
        return;
    }
    
    // Set arrow properties with correct parameter types
    ObjectSetInteger(0, signal_name, OBJPROP_ARROWCODE, (long)arrow_code);
    ObjectSetInteger(0, signal_name, OBJPROP_COLOR, (long)arrow_color);
    ObjectSetInteger(0, signal_name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, signal_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    ObjectSetInteger(0, signal_name, OBJPROP_HIDDEN, 0);
    ObjectSetInteger(0, signal_name, OBJPROP_SELECTABLE, 0);
    ObjectSetInteger(0, signal_name, OBJPROP_SELECTED, 0);
    ObjectSetInteger(0, signal_name, OBJPROP_BACK, 0);
    
    // Create the confidence text
    if(!ObjectCreate(0, conf_name, OBJ_TEXT, 0, time, arrow_price)) {
        Print("Failed to create confidence text object! Error: ", GetLastError());
        return;
    }
    
    // Set text properties with correct parameter types
    ObjectSetString(0, conf_name, OBJPROP_TEXT, IntegerToString(confidence) + "%");
    ObjectSetInteger(0, conf_name, OBJPROP_COLOR, (long)arrow_color);
    ObjectSetInteger(0, conf_name, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, conf_name, OBJPROP_ANCHOR, ANCHOR_LOWER);
    ObjectSetInteger(0, conf_name, OBJPROP_HIDDEN, 0);
    ObjectSetInteger(0, conf_name, OBJPROP_SELECTABLE, 0);
    ObjectSetInteger(0, conf_name, OBJPROP_SELECTED, 0);
    ObjectSetInteger(0, conf_name, OBJPROP_BACK, 0);
    
    // Refresh the chart
    ChartRedraw(0);
}