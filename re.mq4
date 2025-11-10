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
    return (bitblack_4 > bitblack_5 - config.strs && LX == 0);
}

bool ShouldBlockSell() {
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
    if (currentProfit >= 100) {
        CloseThisSymbolAll();
        return 0;
    }
    
    if (currentProfit <= -1000 && total == 3) CloseThisSymbolAll();
    if (currentProfit <= -6000 && total == 2) CloseThisSymbolAll();
    if (currentProfit <= -3000 && total == 5) CloseThisSymbolAll();
    if (currentProfit <= -10000 && total == 6) CloseThisSymbolAll();
    
    // Dynamic pips calculation
    if (DynamicPips) {
        double hival = High[iHighest(NULL, 0, MODE_HIGH, Glubina, 1)];
        double loval = Low[iLowest(NULL, 0, MODE_LOW, Glubina, 1)];
        PipStep = NormalizeDouble((hival - loval) / DEL / Point, 0);
        if (PipStep < DefaultPips / DEL) PipStep = NormalizeDouble(DefaultPips / DEL, 0);
        if (PipStep > DefaultPips * DEL) PipStep = NormalizeDouble(DefaultPips * DEL, 0);
    }
    
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
        if (LongTrade && LastBuyPrice - Ask >= PipStep * Point) TradeNow = TRUE;
        if (ShortTrade && Bid - LastSellPrice >= PipStep * Point) TradeNow = TRUE;
    }
    
    // Open new series
    if (total < 1) {
        ShortTrade = FALSE;
        LongTrade = FALSE;
        TradeNow = TRUE;
    }
    
    // Execute trades
    if (TradeNow) {
        LastBuyPrice = FindLastBuyPrice();
        LastSellPrice = FindLastSellPrice();
        
        if (ShortTrade) {
            NumOfTrades = total;
            double iLots = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), 2);
            RefreshRates();
            ticket = OpenPendingOrder(1, iLots, Bid, MaxSlippage, Ask, 0, 0, 
                                      EAName + "-" + NumOfTrades + "-" + PipStep, MagicNumber, 0, HotPink);
            if (ticket < 0) return 0;
            LastSellPrice = FindLastSellPrice();
            TradeNow = FALSE;
            NewOrdersPlaced = TRUE;
        } else if (LongTrade) {
            NumOfTrades = total;
            iLots = NormalizeDouble(Lots * MathPow(LotExponent, NumOfTrades), 2);
            ticket = OpenPendingOrder(0, iLots, Ask, MaxSlippage, Bid, 0, 0, 
                                      EAName + "-" + NumOfTrades + "-" + PipStep, MagicNumber, 0, Lime);
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
                if (iRSI(NULL, PERIOD_M1, 14, PRICE_CLOSE, 1) < config.rsiMaximum) {
                    ticket = OpenPendingOrder(1, iLots, Bid, MaxSlippage, Bid, 0, 0, 
                                              EAName + "-" + NumOfTrades, MagicNumber, 0, HotPink);
                    if (ticket > 0) NewOrdersPlaced = TRUE;
                }
            } else {
                if (iRSI(NULL, PERIOD_M1, 14, PRICE_CLOSE, 1) > config.rsiMinimum) {
                    ticket = OpenPendingOrder(0, iLots, Ask, MaxSlippage, Ask, 0, 0, 
                                              EAName + "-" + NumOfTrades, MagicNumber, 0, Lime);
                    if (ticket > 0) NewOrdersPlaced = TRUE;
                }
            }
            TradeNow = FALSE;
        }
    }
    
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
    
    if (NewOrdersPlaced) {
        for (cnt = OrdersTotal() - 1; cnt >= 0; cnt--) {
            OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
            if (OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
            
            if (OrderType() == OP_BUY) {
                double PriceTarget = AveragePrice + config.takeProfit * Point;
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
