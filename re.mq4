// BitblackVIP I (reborn) — cleaned and modularized
// โค้ดนี้ปรับให้สะอาดขึ้น โดยคงพฤติกรรมเดิมทุกประการ และใช้ configuration structure
// เปลี่ยนจากการตั้งค่า hardcoded เป็นระบบ configuration ที่ยืดหยุ่น

#property copyright "" 
#property link      ""

//====== CONFIGURATION STRUCTURE ======
struct TradeConfig {
    double stopLoss;
    double trailStart;
    double trailStop;
    double lotExponent;
    double takeProfit;
    double rsiMinimum;
    double rsiMaximum;
    int maxTrades;
    double strs;
};
bool DeletePendingOrders = false;  // ควบคุมการลบ pending orders
int LX = 0;  // สถานะการเทรดหรือสัญญาณ (0=ไม่มี, 1=ขาลง, -1=ขาขึ้น)
struct ModeConfig {
    double lotMultiplier;
    int pipStep;
    double rsiMin;
    double rsiMax;
};

//====== GLOBAL CONFIGURATION ======
TradeConfig config;
ModeConfig modeConfigs[4]; // 0=SafeMode, 1=NormalMode, 2=Speculatemode, 3=ALLinmode

//====== CONFIGURATION INITIALIZATION ======
void InitializeConfiguration() {
    // Default configuration
    config.stopLoss = 500.0;
    config.trailStart = 10.0;
    config.trailStop = 10.0;
    config.lotExponent = 1.62;
    config.takeProfit = 100.0;
    config.rsiMinimum = 40.0;
    config.rsiMaximum = 60.0;
    config.maxTrades = 30;
    config.strs = 0.00010;
    
    // Safe Mode: Conservative
    modeConfigs[0].lotMultiplier = 2.03;
    modeConfigs[0].pipStep = 35;
    modeConfigs[0].rsiMin = 40.0;
    modeConfigs[0].rsiMax = 60.0;
    
    // Normal Mode: Balanced
    modeConfigs[1].lotMultiplier = 2.32;
    modeConfigs[1].pipStep = 40;
    modeConfigs[1].rsiMin = 40.0;
    modeConfigs[1].rsiMax = 60.0;
    
    // Speculate Mode: Aggressive
    modeConfigs[2].lotMultiplier = 2.0;
    modeConfigs[2].pipStep = 55;
    modeConfigs[2].rsiMin = 40.0;
    modeConfigs[2].rsiMax = 60.0;
    
    // All-In Mode: Maximum
    modeConfigs[3].lotMultiplier = 2.2;
    modeConfigs[3].pipStep = 40;
    modeConfigs[3].rsiMin = 0.0;
    modeConfigs[3].rsiMax = 100.0;
}

//====== INPUT PARAMETERS ======
extern double Stoploss = 500.0;
extern double TrailStart = 10.0;
extern double TrailStop = 10.0;
extern double LotExponent = 1.62;
extern double Lots = 0.01;
extern double TakeProfit = 100.0;
extern double Strs = 0.00010;
extern double RsiMinimum = 40.0;
extern double RsiMaximum = 60.0;
extern int MaxTrades = 30;
extern int DefaultPips = 35;
extern int Glubina = 20;
extern int DEL = 3;
extern int MaxSlippage = 5;
extern double LotExponent_Input = 1.62;
extern bool DynamicPips = true;
extern bool UseEquityStop = false;
extern double TotalEquityRisk = 20.0;
extern bool UseTrailingStop = FALSE;
extern bool UseTimeOut = true;
extern double MaxTradeOpenHours = 10.0;

//====== TRADING MODE INPUTS ======
extern bool SafeMode = FALSE;
extern bool NormalMode = FALSE;
extern bool Speculatemode = FALSE;
extern bool ALLinmode = FALSE;
extern bool ONLYBUYMODE = TRUE;
extern bool ONLYSELLMODE = FALSE;
extern int MajorTrendMAPeriod = 200;
extern double TrendBufferPoints = 10.0;
extern int ADRPeriod = 30;
extern double ADRBaselinePoints = 3000.0;
extern double ADRInfluence = 0.6;

//====== GLOBAL VARIABLES ======
int MagicNumber = 123456;
string EAName = "BitblackVIP I";
double Spread;
int timeprev = 0;
int NumOfTrades = 0;
int cnt = 0, total = 0;
bool TradeNow = FALSE, LongTrade = FALSE, ShortTrade = FALSE;
bool NewOrdersPlaced = FALSE;
bool flag = FALSE;
int PipStep = 0;
double LastBuyPrice = 0;
double LastSellPrice = 0;
double AveragePrice = 0;
double Stopper = 0.0;
int ticket = 0;
int MajorTrendDirection = 0;
int LastMajorTrendDirection = 0;
bool AllowBuy = TRUE;
bool AllowSell = TRUE;
double BaseGridStep = 0.0;
double AdaptiveGridStep = 0.0;

// Indicator buffers
double bitblack_1 = 10;
double bitblack_2 = 10;
double bitblack_3 = 10;
double bitblack_4 = 10;
double bitblack_5 = 10;
double bitblack_6 = 10;

// Tracking variables
double savelot = 0;
int buycount = 0;
int sellcount = 0;
double PrevEquity = 0;
double AccountEquityHighAmt = 0;

//====== UI HELPER FUNCTIONS ======
void CreateLabelSimple(string name, int x, int y, string text, int size, color col) {
    ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
    ObjectSet(name, OBJPROP_XDISTANCE, x);
    ObjectSet(name, OBJPROP_YDISTANCE, y);
    ObjectSetText(name, text, size, "Fixedsys", col);
}

void SetLabelText(string name, string text, int size, color col) {
    ObjectSetText(name, text, size, "Fixedsys", col);
}

//====== TRADING CONDITION HELPERS ======
bool ShouldBlockBuy() {
    if (!AllowBuy) return true;
    return (bitblack_4 > bitblack_5 - config.strs && LX == 0);
}

bool ShouldBlockSell() {
    if (!AllowSell) return true;
    return (bitblack_4 - config.strs < bitblack_5 && LX == 0);
}

//====== GET ACTIVE MODE ======
int GetActiveMode() {
    if (SafeMode) return 0;
    if (NormalMode) return 1;
    if (Speculatemode) return 2;
    if (ALLinmode) return 3;
    return 1; // Default to Normal Mode
}

//====== TREND ANALYSIS ======
int DetermineMajorTrend() {
    double maH1 = iMA(NULL, PERIOD_H1, MajorTrendMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
    double priceH1 = iClose(NULL, PERIOD_H1, 1);
    double maH4 = iMA(NULL, PERIOD_H4, MajorTrendMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
    double priceH4 = iClose(NULL, PERIOD_H4, 1);

    int trendH1 = 0;
    int trendH4 = 0;

    if (priceH1 > maH1 + TrendBufferPoints * Point) trendH1 = 1;
    else if (priceH1 < maH1 - TrendBufferPoints * Point) trendH1 = -1;

    if (priceH4 > maH4 + TrendBufferPoints * Point) trendH4 = 1;
    else if (priceH4 < maH4 - TrendBufferPoints * Point) trendH4 = -1;

    if (trendH1 == trendH4) return trendH1;
    if (trendH4 != 0) return trendH4;
    return trendH1;
}

//====== AVERAGE DAILY RANGE ======
double CalculateADRPoints(int period) {
    double adr = iATR(NULL, PERIOD_D1, period, 1);
    if (adr <= 0.0) return 0.0;
    return adr / Point;
}

double ApplyADRScaling(double baseStep) {
    double adrPoints = CalculateADRPoints(ADRPeriod);
    if (adrPoints <= 0.0 || ADRBaselinePoints <= 0.0) return baseStep;

    double factor = adrPoints / ADRBaselinePoints;
    double adjustedFactor = 1.0 + (factor - 1.0) * ADRInfluence;
    double minFactor = 0.7;
    double maxFactor = 1.6;
    if (adjustedFactor < minFactor) adjustedFactor = minFactor;
    if (adjustedFactor > maxFactor) adjustedFactor = maxFactor;

    double scaledStep = baseStep * adjustedFactor;
    double minStep = baseStep * 0.6;
    double maxStep = baseStep * 1.6;
    if (scaledStep < minStep) scaledStep = minStep;
    if (scaledStep > maxStep) scaledStep = maxStep;

    return scaledStep;
}

double GetAdaptiveGridStep(int tradeIndex, double baseStep) {
    if (baseStep <= 0.0) return 0.0;

    if (tradeIndex <= 0) return baseStep * 1.3;
    if (tradeIndex == 1) return baseStep * 1.2;

    if (tradeIndex <= 4) {
        double multipliers[3] = {1.0, 0.95, 0.9};
        return baseStep * multipliers[tradeIndex - 2];
    }

    double laterMultiplier = 1.05 + MathMin(0.1, (tradeIndex - 5) * 0.02);
    if (laterMultiplier > 1.2) laterMultiplier = 1.2;
    return baseStep * laterMultiplier;
}

string GetModeName(int mode) {
    switch(mode) {
        case 0: return "SafeMode";
        case 1: return "NormalMode";
        case 2: return "Speculatemode";
        case 3: return "ALLinmode";
        default: return "UnknownMode";
    }
}

//====== INDICATOR UPDATE ======
void UpdateIndicators() {
    bitblack_1 = iCustom(NULL, 0, "uLinRegrBuf", 0, 1);
    bitblack_2 = iCustom(NULL, 0, "uLinRegrBuf", 1, 1);
    bitblack_3 = iCustom(NULL, 0, "uLinRegrBuf", 2, 1);
    bitblack_4 = iCustom(NULL, 0, "Bitblackin", 2, 1);
    bitblack_5 = iCustom(NULL, 0, "Bitblackin", 3, 1);
}

//====== PROFIT CALCULATION ======
double CalculateProfit() {
    double Profit = 0;
    for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
        OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
        if (OrderType() == OP_BUY || OrderType() == OP_SELL) 
            Profit += OrderProfit();
    }
    return Profit;
}

//====== COUNT TRADES ======
int CountTrades() {
    int count = 0;
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
        OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
        if (OrderType() == OP_SELL || OrderType() == OP_BUY) count++;
    }
    return count;
}

//====== FIND LAST PRICES ======
double FindLastBuyPrice() {
    double oldorderopenprice = 0;
    int ticketnumber = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
        OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
        if (OrderType() == OP_BUY) {
            int oldticketnumber = OrderTicket();
            if (oldticketnumber > ticketnumber) {
                oldorderopenprice = OrderOpenPrice();
                ticketnumber = oldticketnumber;
            }
        }
    }
    return oldorderopenprice;
}

double FindLastSellPrice() {
    double oldorderopenprice = 0;
    int ticketnumber = 0;
    for (int cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
        OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
        if (OrderType() == OP_SELL) {
            int oldticketnumber = OrderTicket();
            if (oldticketnumber > ticketnumber) {
                oldorderopenprice = OrderOpenPrice();
                ticketnumber = oldticketnumber;
            }
        }
    }
    return oldorderopenprice;
}

//====== STOP & TAKE PROFIT CALCULATION ======
double StopLong(double price, int stop) {
    if (stop == 0) return 0;
    return price - stop * Point;
}

double StopShort(double price, int stop) {
    if (stop == 0) return 0;
    return price + stop * Point;
}

double TakeLong(double price, int stop) {
    if (stop == 0) return 0;
    return price + stop * Point;
}

double TakeShort(double price, int stop) {
    if (stop == 0) return 0;
    return price - stop * Point;
}

//====== CLOSE ORDERS ======
void CloseThisSymbolAll() {
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
        OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
            if (OrderType() == OP_BUY) 
                OrderClose(OrderTicket(), OrderLots(), Bid, MaxSlippage, Blue);
            if (OrderType() == OP_SELL) 
                OrderClose(OrderTicket(), OrderLots(), Ask, MaxSlippage, Red);
            Sleep(500);
        }
    }
}

//====== TRAILING STOP ======
void TrailingAlls(int pType, int stop, double AvgPrice) {
    if (stop == 0) return;
    
    for (int trade = OrdersTotal() - 1; trade >= 0; trade--) {
        if (!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
        
        if (OrderType() == OP_BUY) {
            int profit = NormalizeDouble((Bid - AvgPrice) / Point, 0);
            if (profit >= pType) {
                double stoptrade = OrderStopLoss();
                double stopcal = Bid - stop * Point;
                if (stoptrade == 0.0 || (stoptrade != 0.0 && stopcal > stoptrade)) 
                    OrderModify(OrderTicket(), AvgPrice, stopcal, OrderTakeProfit(), 0, Aqua);
            }
        }
        if (OrderType() == OP_SELL) {
            profit = NormalizeDouble((AvgPrice - Ask) / Point, 0);
            if (profit >= pType) {
                stoptrade = OrderStopLoss();
                stopcal = Ask + stop * Point;
                if (stoptrade == 0.0 || (stoptrade != 0.0 && stopcal < stoptrade)) 
                    OrderModify(OrderTicket(), AvgPrice, stopcal, OrderTakeProfit(), 0, Red);
            }
        }
        Sleep(500);
    }
}

//====== ACCOUNT EQUITY HIGH ======
double AccountEquityHigh() {
    if (CountTrades() == 0) AccountEquityHighAmt = AccountEquity();
    if (AccountEquityHighAmt < PrevEquity) AccountEquityHighAmt = PrevEquity;
    else AccountEquityHighAmt = AccountEquity();
    PrevEquity = AccountEquity();
    return AccountEquityHighAmt;
}

//====== OPEN PENDING ORDER ======
int OpenPendingOrder(int pType, double pLots, double pLevel, int sp, double pr, 
                     int sl, int tp, string pComment, int pMagic, int pDatetime, color pColor) {
    int ticket = 0;
    int err = 0;
    int c = 0;
    int NumberOfTries = 10;
    
    // Adjust lots based on trade count
    if (total < 1) pLots = (Lots + 0.3) * 1;
    if (total > 1) pLots = (Lots + 0.3) * total;
    if (pLots >= 8) pLots = 8;
    
    UpdateIndicators();
    
    switch (pType) {
        case 0: // OP_BUY
            if (ShouldBlockBuy()) break;
            for (c = 0; c < NumberOfTries; c++) {
                buycount++;
                RefreshRates();
                ticket = OrderSend(Symbol(), OP_BUY, pLots, NormalizeDouble(Ask, Digits), sp, 
                                   NormalizeDouble(StopLong(Bid, sl), Digits), 
                                   NormalizeDouble(TakeLong(Ask, tp), Digits), 
                                   pComment, pMagic, pDatetime, pColor);
                err = GetLastError();
                if (err == 0) break;
                if (!(err == 4 || err == 137 || err == 146 || err == 136)) break;
                Sleep(10000);
            }
            savelot = savelot + pLots;
            break;
            
        case 1: // OP_SELL
            if (ShouldBlockSell()) break;
            for (c = 0; c < NumberOfTries; c++) {
                sellcount++;
                ticket = OrderSend(Symbol(), OP_SELL, pLots, NormalizeDouble(Bid, Digits), sp, 
                                   NormalizeDouble(StopShort(Ask, sl), Digits), 
                                   NormalizeDouble(TakeShort(Bid, tp), Digits), 
                                   pComment, pMagic, pDatetime, pColor);
                err = GetLastError();
                if (err == 0) break;
                if (!(err == 4 || err == 137 || err == 146 || err == 136)) break;
                Sleep(10000);
            }
            savelot = savelot + pLots;
            break;
            
        case 2: // OP_BUYLIMIT
            if (ShouldBlockBuy()) break;
            for (c = 0; c < NumberOfTries; c++) {
                ticket = OrderSend(Symbol(), OP_BUYLIMIT, pLots, pLevel, sp, 
                                   StopLong(pr, sl), TakeLong(pLevel, tp), 
                                   pComment, pMagic, pDatetime, pColor);
                err = GetLastError();
                if (err == 0) break;
                if (!(err == 4 || err == 137 || err == 146 || err == 136)) break;
                Sleep(10000);
            }
            break;
            
        case 3: // OP_SELLLIMIT
            if (ShouldBlockSell()) break;
            for (c = 0; c < NumberOfTries; c++) {
                ticket = OrderSend(Symbol(), OP_SELLLIMIT, pLots, pLevel, sp, 
                                   StopShort(pr, sl), TakeShort(pLevel, tp), 
                                   pComment, pMagic, pDatetime, pColor);
                err = GetLastError();
                if (err == 0) break;
                if (!(err == 4 || err == 137 || err == 146 || err == 136)) break;
                Sleep(10000);
            }
            break;
            
        case 4: // OP_BUYSTOP
            if (ShouldBlockBuy()) break;
            for (c = 0; c < NumberOfTries; c++) {
                ticket = OrderSend(Symbol(), OP_BUYSTOP, pLots, pLevel, sp, 
                                   StopLong(pr, sl), TakeLong(pLevel, tp), 
                                   pComment, pMagic, pDatetime, pColor);
                err = GetLastError();
                if (err == 0) break;
                if (!(err == 4 || err == 137 || err == 146 || err == 136)) break;
                Sleep(10000);
            }
            break;
            
        case 5: // OP_SELLSTOP
            if (ShouldBlockSell()) break;
            for (c = 0; c < NumberOfTries; c++) {
                ticket = OrderSend(Symbol(), OP_SELLSTOP, pLots, pLevel, sp, 
                                   StopShort(pr, sl), TakeShort(pLevel, tp), 
                                   pComment, pMagic, pDatetime, pColor);
                err = GetLastError();
                if (err == 0) break;
                if (!(err == 4 || err == 137 || err == 146 || err == 136)) break;
                Sleep(10000);
            }
            break;
    }
    return ticket;
}

//====== CLOSE ALL ORDERS (VARIOUS MODES) ======
void CloseAllOrdersV01(bool boolPendingOrders, int intMaxSlippage) {
    bool checkOrderClose = true;
    int index = OrdersTotal() - 1;
    
    while (index >= 0 && OrderSelect(index, SELECT_BY_POS, MODE_TRADES)) {
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == 0 && 
            (OrderType() == OP_BUY || OrderType() == OP_SELL)) {
            checkOrderClose = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), intMaxSlippage, CLR_NONE);
        }
        else if (boolPendingOrders && OrderSymbol() == Symbol() && OrderMagicNumber() == 0 && 
                 OrderType() != OP_BUY && OrderType() != OP_SELL) {
            checkOrderClose = OrderDelete(OrderTicket(), CLR_NONE);
        }
        
        if (!checkOrderClose) {
            int errorCode = GetLastError();
            if (errorCode == 1 || errorCode == 2 || errorCode == 5 || errorCode == 6 || 
                errorCode == 64 || errorCode == 65 || errorCode == 132 || errorCode == 133 || 
                errorCode == 139) break;
        }
        index--;
    }
}

void CloseAllOrdersV02(bool boolPendingOrders, int intMaxSlippage) {
    bool checkOrderClose = true;
    int index = OrdersTotal() - 1;
    
    while (index >= 0 && OrderSelect(index, SELECT_BY_POS, MODE_TRADES)) {
        if (OrderSymbol() == Symbol() && (OrderType() == OP_BUY || OrderType() == OP_SELL)) {
            checkOrderClose = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), intMaxSlippage, CLR_NONE);
        }
        else if (boolPendingOrders && OrderSymbol() == Symbol() && 
                 OrderType() != OP_BUY && OrderType() != OP_SELL) {
            checkOrderClose = OrderDelete(OrderTicket(), CLR_NONE);
        }
        
        if (!checkOrderClose) {
            int errorCode = GetLastError();
            if (errorCode == 1 || errorCode == 2 || errorCode == 5 || errorCode == 6 || 
                errorCode == 64 || errorCode == 65 || errorCode == 132 || errorCode == 133 || 
                errorCode == 139) break;
        }
        index--;
    }
}

void CloseAllOrdersV03(bool boolPendingOrders, int intMaxSlippage) {
    bool checkOrderClose = true;
    int index = OrdersTotal() - 1;
    
    while (index >= 0 && OrderSelect(index, SELECT_BY_POS, MODE_TRADES)) {
        if ((OrderType() == OP_BUY || OrderType() == OP_SELL) && OrderMagicNumber() == 0) {
            checkOrderClose = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), intMaxSlippage, CLR_NONE);
        }
        else if (boolPendingOrders && OrderType() != OP_BUY && OrderType() != OP_SELL && 
                 OrderMagicNumber() == 0) {
            checkOrderClose = OrderDelete(OrderTicket(), CLR_NONE);
        }
        
        if (!checkOrderClose) {
            int errorCode = GetLastError();
            if (errorCode == 1 || errorCode == 2 || errorCode == 5 || errorCode == 6 || 
                errorCode == 64 || errorCode == 65 || errorCode == 132 || errorCode == 133 || 
                errorCode == 139) break;
        }
        index--;
    }
}

void CloseAllOrdersV04(bool boolPendingOrders, int intMaxSlippage) {
    bool checkOrderClose = true;
    int index = OrdersTotal() - 1;
    
    while (index >= 0 && OrderSelect(index, SELECT_BY_POS, MODE_TRADES)) {
        if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
            checkOrderClose = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), intMaxSlippage, CLR_NONE);
        }
        else if (boolPendingOrders && OrderType() != OP_BUY && OrderType() != OP_SELL) {
            checkOrderClose = OrderDelete(OrderTicket(), CLR_NONE);
        }
        
        if (!checkOrderClose) {
            int errorCode = GetLastError();
            if (errorCode == 1 || errorCode == 2 || errorCode == 5 || errorCode == 6 || 
                errorCode == 64 || errorCode == 65 || errorCode == 132 || errorCode == 133 || 
                errorCode == 139) break;
        }
        index--;
    }
}

//====== CHART EVENT HANDLER ======
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    if (sparam == "CloseButton") {
        bool runCurrent = true; // RunOnCurrentCurrencyPair
        bool closeManual = true; // CloseOnlyManualTrades
        
        if (runCurrent && closeManual) CloseAllOrdersV01(DeletePendingOrders, MaxSlippage);
        else if (runCurrent && !closeManual) CloseAllOrdersV02(DeletePendingOrders, MaxSlippage);
        else if (!runCurrent && closeManual) CloseAllOrdersV03(DeletePendingOrders, MaxSlippage);
        else if (!runCurrent && !closeManual) CloseAllOrdersV04(DeletePendingOrders, MaxSlippage);
        
        ObjectSetInteger(0, "CloseButton", OBJPROP_STATE, false);
    }
}

//====== INITIALIZATION ======
int init() {
    InitializeConfiguration();
    Spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
    return 0;
}

//====== DEINITIALIZATION ======
int deinit() {
    return 0;
}

//====== MAIN START FUNCTION ======
int start() {
    int activeMode = GetActiveMode();
    string modeName = GetModeName(activeMode);
    
    // Display current mode
    CreateLabelSimple("ModeLabel", 300, 10, modeName, 20, Lime);

    // Close based on profit levels
    double currentProfit = CalculateProfit();
    double iLots = 0.0;
    total = CountTrades();

    if (currentProfit >= 100) {
        CloseThisSymbolAll();
        return 0;
    }

    if (currentProfit <= -1000 && total == 3) CloseThisSymbolAll();
    if (currentProfit <= -6000 && total == 2) CloseThisSymbolAll();
    if (currentProfit <= -3000 && total == 5) CloseThisSymbolAll();
    if (currentProfit <= -10000 && total == 6) CloseThisSymbolAll();

    // Determine major trend and trading permissions
    MajorTrendDirection = DetermineMajorTrend();
    AllowBuy = !ONLYSELLMODE;
    AllowSell = !ONLYBUYMODE;
    if (MajorTrendDirection == 1) AllowSell = false;
    else if (MajorTrendDirection == -1) AllowBuy = false;

    if (LastMajorTrendDirection != 0 && MajorTrendDirection != 0 &&
        MajorTrendDirection != LastMajorTrendDirection && total > 0 && total < 4) {
        CloseThisSymbolAll();
        LongTrade = FALSE;
        ShortTrade = FALSE;
        TradeNow = FALSE;
        LastMajorTrendDirection = MajorTrendDirection;
        return 0;
    }

    // Dynamic pips calculation with ADR adjustment
    double rawStep = DefaultPips;
    if (DynamicPips) {
        double hival = High[iHighest(NULL, 0, MODE_HIGH, Glubina, 1)];
        double loval = Low[iLowest(NULL, 0, MODE_LOW, Glubina, 1)];
        rawStep = (hival - loval) / DEL / Point;
        if (rawStep < DefaultPips / DEL) rawStep = DefaultPips / DEL;
        if (rawStep > DefaultPips * DEL) rawStep = DefaultPips * DEL;
    }

    if (rawStep <= 0.0) rawStep = DefaultPips;
    BaseGridStep = NormalizeDouble(ApplyADRScaling(rawStep), 2);
    if (BaseGridStep <= 0.0) BaseGridStep = DefaultPips;
    AdaptiveGridStep = NormalizeDouble(GetAdaptiveGridStep(total, BaseGridStep), 2);
    if (AdaptiveGridStep <= 0.0) AdaptiveGridStep = BaseGridStep;
    PipStep = (int)NormalizeDouble(AdaptiveGridStep, 0);

    // Time filtering
    if (UseTrailingStop) TrailingAlls(TrailStart, TrailStop, AveragePrice);

    if (UseTimeOut && ((iCCI(NULL, 15, 55, 0, 0) > 1000000 && ShortTrade) ||
        (iCCI(NULL, 15, 55, 0, 0) < -1000000 && LongTrade))) {
        CloseThisSymbolAll();
        return 0;
    }

    if (timeprev == Time[0]) return 0;
    timeprev = Time[0];

    // Equity stop loss
    currentProfit = CalculateProfit();
    if (UseEquityStop) {
        if (currentProfit < 0.0 && MathAbs(currentProfit) > TotalEquityRisk / 100.0 * AccountEquityHigh()) {
            CloseThisSymbolAll();
            return 0;
        }
    }

    total = CountTrades();
    if (total == 0) flag = FALSE;
    
    // Detect trade direction
    for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
        OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
        
        if (OrderType() == OP_BUY) {
            LongTrade = TRUE;
            ShortTrade = FALSE;
            break;
        }
        if (OrderType() == OP_SELL) {
            LongTrade = FALSE;
            ShortTrade = TRUE;
            break;
        }
    }
    
    // Manage existing trades
    if (total > 0 && total <= config.maxTrades) {
        RefreshRates();
        LastBuyPrice = FindLastBuyPrice();
        LastSellPrice = FindLastSellPrice();
        if (LongTrade && AllowBuy && LastBuyPrice - Ask >= AdaptiveGridStep * Point) TradeNow = TRUE;
        if (ShortTrade && AllowSell && Bid - LastSellPrice >= AdaptiveGridStep * Point) TradeNow = TRUE;
    }

    // Open new series
    if (total < 1) {
        ShortTrade = FALSE;
        LongTrade = FALSE;
        TradeNow = (AllowBuy || AllowSell);
    }

    // Execute trades
    if (TradeNow) {
        LastBuyPrice = FindLastBuyPrice();
        LastSellPrice = FindLastSellPrice();

        if (ShortTrade && AllowSell) {
            NumOfTrades = total;
            iLots = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), 2);
            RefreshRates();
            string sellComment = EAName + "-" + NumOfTrades + "-" + DoubleToStr(AdaptiveGridStep, 1);
            ticket = OpenPendingOrder(1, iLots, Bid, MaxSlippage, Ask, 0, 0,
                                      sellComment, MagicNumber, 0, HotPink);
            if (ticket < 0) return 0;
            LastSellPrice = FindLastSellPrice();
            TradeNow = FALSE;
            NewOrdersPlaced = TRUE;
        } else if (LongTrade && AllowBuy) {
            NumOfTrades = total;
            iLots = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), 2);
            string buyComment = EAName + "-" + NumOfTrades + "-" + DoubleToStr(AdaptiveGridStep, 1);
            ticket = OpenPendingOrder(0, iLots, Ask, MaxSlippage, Bid, 0, 0,
                                      buyComment, MagicNumber, 0, Lime);
            if (ticket < 0) return 0;
            LastBuyPrice = FindLastBuyPrice();
            TradeNow = FALSE;
            NewOrdersPlaced = TRUE;
        }
    }

    // Open first trades
    if (TradeNow && total < 1) {
        double PrevCl = iClose(Symbol(), 0, 2);
        double CurrCl = iClose(Symbol(), 0, 1);
        
        if (!ShortTrade && !LongTrade) {
            NumOfTrades = total;
             iLots = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), 2);
            
            if (PrevCl > CurrCl) {
                if (AllowSell && iRSI(NULL, PERIOD_M1, 14, PRICE_CLOSE, 1) < config.rsiMaximum) {
                    ticket = OpenPendingOrder(1, iLots, Bid, MaxSlippage, Bid, 0, 0,
                                              EAName + "-" + NumOfTrades, MagicNumber, 0, HotPink);
                    if (ticket > 0) NewOrdersPlaced = TRUE;
                }
            } else {
                if (AllowBuy && iRSI(NULL, PERIOD_M1, 14, PRICE_CLOSE, 1) > config.rsiMinimum) {
                    ticket = OpenPendingOrder(0, iLots, Ask, MaxSlippage, Ask, 0, 0,
                                              EAName + "-" + NumOfTrades, MagicNumber, 0, Lime);
                    if (ticket > 0) NewOrdersPlaced = TRUE;
                }
            }
            TradeNow = FALSE;
        }
    }

    LastMajorTrendDirection = MajorTrendDirection;
    
    // Calculate average price and update TP/SL
    total = CountTrades();
    AveragePrice = 0;
    double Count = 0;
    for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
        OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
        if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
        if (OrderType() == OP_BUY || OrderType() == OP_SELL) {
            AveragePrice += OrderOpenPrice() * OrderLots();
            Count += OrderLots();
        }
    }
    if (total > 0) AveragePrice = NormalizeDouble(AveragePrice / Count, Digits);
    
    double PriceTarget = 0.0;
    if (NewOrdersPlaced) {
        for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
            OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
            if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;

            if (OrderType() == OP_BUY) {
                PriceTarget = AveragePrice + config.takeProfit * Point;
                Stopper = AveragePrice - config.stopLoss * Point;
                flag = TRUE;
            }
            if (OrderType() == OP_SELL) {
                PriceTarget = AveragePrice - config.takeProfit * Point;
                Stopper = AveragePrice + config.stopLoss * Point;
                flag = TRUE;
            }
        }
    }
    
    if (NewOrdersPlaced && flag) {
        for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
            OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
            if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
            OrderModify(OrderTicket(), NormalizeDouble(AveragePrice, Digits), 
                       NormalizeDouble(OrderStopLoss(), Digits), 
                       NormalizeDouble(PriceTarget, Digits), 0, Yellow);
            NewOrdersPlaced = FALSE;
        }
    }
    
    return 0;
}
