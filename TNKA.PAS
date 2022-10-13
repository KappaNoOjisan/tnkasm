{                                                  }
{     TNKA Version 1.00                            }
{         copyright (c) 1993,2022 K.Watanuki       }

Program TnkA;

  Uses Drivers;


  Const

    Linel  =  80;
    Namel  =  16;
    Nrw    = 256;
    Lmax   = 800;
    Emax   =  30;

    FirStMsg : String[Linel]
      =('START');

    SecondMsg: String[Linel]
      =('END.');

  type
    TOutFmt = ( HEX_FORMAT, BIN_FORMAT );

  Var
    Option : Record
        Help   : Boolean;
        Print  : Boolean;
        Format : TOutFmt;
    end;

  type

      TErrOrd = (
        erSTX_ERR, { Syntax error.     0 }
        erDUP_LBL, { Duplicate Label.  1 }
        erUDF_LBL, { Undefined Label.  2 }
        erJMP_FAR, { Jump too far.     3 }
        erBAD_EXP, { Bad expression.   4 }
        erOPR_OVR, { Operand overflow. 5 }
        erLNG_LBL, { Name too long.    6 }
        erCMP_OPR, { Complexed Operand.7 }
        erCNT_INC  { Cannot include.   8 }
      );

  const
      ErrMsg   : Array [TErrOrd] of String[18]
               =('Syntax error.     ',     { 0 }
                 'Duplicate Label.  ',     { 1 }
                 'Undefined Label.  ',     { 2 }
                 'Jump too far.     ',     { 3 }
                 'Bad expression.   ',     { 4 }
                 'Operand overflow. ',     { 5 }
                 'Long Label.       ',     { 6 }
                 'Complexed Operand.',     { 7 }
                 'File not found.   '      { 8 }
                );

      HdConst  : Array [0..15] of Byte
               =($FF,$30,$00,$00,
                 $10,$00,$00,$00,
                 $00,$00,$00,$00,
                 $00,$00,$00,$00);

  Type
      TPassCount       = 1..2;
      TErrIndex        = 1..Emax;

      TLabelIndex      = 1..Lmax;

      TLabelString     = String[Namel];
      TCardString      = String[Linel];
      PCardString      = ^TCardString;
      TFileString      = String[80];

      Optype     = ( Notype,        Relative,
                     QuickByteLoad, ByteLoad,
                     QuickWordLoad, WordLoad,
                     MacroInst,     CtlInst,
                     DefInst   );

      SymbolKind = ( BadSymbol,
                     Identifier, Number,     Letter,
                     EndofLine,  EndofFile,

                     Leftparen,  Rightparen,
                     Asterisk,   Slush,      Plus,    Minus,
                     Semicolon,  Colon,      Dot,     BackSlush,

                     _AND,       _OR,        _XOR,    _NOT,
                     HighByte,   LowByte,

                     ORG,   PRINT, EQU,   DB,    DS,    DW,    DM,
                     DH,     _END, INCLUDE,


                     ADB,   ADCM,  ADIA,  ADIM,  ADM,   ADN,   ADW,
                     ANIA,  ANID,  ANIM,  ANMA,  CAL,   CALL,  CLRA,
                     CPIA,  CPIM,  CPMA,  DECA,  DECB,  DECI,  DECJ,
                     DECK,  DECL,  DECM,  DECN,  DECP,  DX,    DXL,
                     DY,    DYS,   EXAB,  EXAM,  EXB,   EXBD,  EXW,
                     EXWD,  FILD,  FILM,  INA,   INB,   INCA,  INCB,
                     INCI,  INCJ,  INCK,  INCL,  INCM,  INCN,  INCP,
                     IY,    IYS,   IX,    IXL,   JP,    JPC,   JPNC,
                     JPNZ,  JPZ,   JRCM,  JRCP,  JRM,   JRNCM, JRNCP,
                     JRNZM, JRNZP, JRP,   JRZM,  JRZP,  LEAVE, LDD,
                     LDM,   LDP,   LDPC,  LDQ,   LDR,   LIA,   LIB,
                     LIDL,  LIDP,  LII,   LIJ,   LIP,   LIQ,   LOOP,
                     LP,    MVB,   MVBD,  MVDM,  MVMD,  MVMP,  MVW,
                     MVWD,  MVWP,  NOPT,  NOPW,  ORIA,  ORID,  ORIM,
                     ORMA,  OUTA,  OUTB,  OUTF,  OUTC,  POP,   PUSH,
                     RC,    RTN,   SBB,   SBCM,  SBIA,  SBIM,  SBM,
                     SBN,   SBW,   SC,    SL,    SLW,   SR,    SRW,
                     STD,   STP,   STQ,   STR,   SWP,   TEST,  TSIA,
                     TSID,  TSIM,  TSMA,  WAIT
                   );

      Symbolset = Set of SymbolKind;

      BinFile   = File of Byte;

  Var
      InputF,
      IncludeF     : Text;
      OutputF      : BinFile;

      IncludeSw    : Boolean;

      PassCount    : TPassCount;

      LabelCount   : 0..Lmax;
      LabelPtr     : TLabelIndex;
      LabelTable   : Array [TLabelIndex] of
                     Record
                       Name  : TLabelString;
                       Value : Word;
                     end;

      Idtable      : Array [BYTE] of
                     Record
                       Name  : TLabelString;
                       Value : Word
                     end;

      RwCount      : 0..Nrw;
      ReservedWord : Array [0..Nrw] of
                     Record
                       Name  : TLabelString;
                       Value : Symbolkind;
                     end;

      SpecialSymbol: Array [Char] of Symbolkind;
      CodeTable    : Array [Symbolkind] of
                     Record
                       Opcode      : Byte;
                       OperandType : OpType;
                     end;

      FactorHead   : Symbolset;

      Ch           : Char;
      cc,ll,pp     : Integer;

      TnkSource    : TCardString;

      Symbol       : SymbolKind;
      BackJumpOp   : Set of SymbolKind;

      Id           : TLabelString;
      NumValue     : LongInt;
      Strings      : TCardString;
      OprStr       : TCardString;
      TnkLabel     : TCardString;

      Hord : Array ['0'..'F'] of byte;

      Errpos       : 0..linel;
      ErrorCount   : 0..Emax;
      ErrTable     : Array [TErrIndex] of
                     Record
                       Cnt    : Word;
                       Pos    : Word;
                       Erno   : Byte;
                       FileNo : Byte;
                     end;
      SourceFile,
      IncludeFile,
      ObjectFile   : TFileString;

      FileFail     : Boolean;

      IncludeCount : Byte;
      IncTable     : Array[1..4] of TCardString;

      Location,
      Top,
      Bottom       : Word;

      InCount,
      InCountSv    : Word;

      TnkList      : TCardString;
      TnkComment   : TCardString;
      TnkOperand   : TCardString;
      TnkOp        : TLabelString;

      TnkObjs      : ^Byte;

{                       }
{  Error                }
{                       }
Procedure Fatal(S: String);
begin
  Writeln(S);
  Halt(3);
end;

Procedure Error(n : TErrOrd);
begin

  if ErrorCount = Emax then
    Exit;

  Inc(ErrorCount);
  with Errtable[ErrorCount] do
  begin
    Cnt    := InCount;
    Pos    := ErrPos;
    Erno   := Ord(n);
    if IncludeSw
      then FileNo := IncludeCount
      else FileNo := 0
  end;

end;

{                       }
{    Calculate Value    }
{                       }
Function ValueNbase(Base: Byte; S: TLabelString) : LongInt;
Var
  i    : Byte;
  Temp : LongInt;
begin
  Temp := 0;
  for i := 1 to Length(S) do
    Temp := Base * Temp + HOrd[ UpCase(S[i]) ];
  ValueNbase := Temp
end;


{                       }
{    Hexadecimal Value  }
{                       }
Function HexStringB(Dec: Byte) : TLabelString;
const
  Xtbl : Array [0..15] of Char = (
           '0','1','2','3','4','5','6','7',
           '8','9','A','B','C','D','E','F'
         );
Var
  T    : Array [0..1] of Byte;
  i    : Byte;
  Work : TLabelString;
  C    : Byte;
begin
  T[0] := Dec div 16;
  T[1] := Dec mod 16;
  Work := '';
  for i := 0 to 1 do
    Work := Work + XTbl[T[i]];
  HexStringB := Work
end;


{                           }
{    Hexadecimal Value      }
{                           }
Function HexStringW( Dec: Word ) : TLabelString;
begin
  HexStringW := HexStringB( Hi(Dec) ) + HexStringB( Lo(Dec) )
end;


{                                }
{  GetSymbol                     }
{                                }
Procedure GetSymbol;
  Label 1;
  Var   i,j,k    : integer;
        IdNumber : TLabelString;
        IsBin    : Boolean;
        IsHex    : Boolean;

 {                    }
 {    GetNextCh       }
 {                    }
  Procedure GetNextch;
    Label 1;
    begin
      if cc = ll then
      begin
        if IncludeSw then
        begin
          if Eof(IncludeF) then
          begin
            Close(IncludeF);
            IncludeSw := False;
            InCount   := InCountSv;
          end
        end
        else if Eof(InputF) then
        begin
          TnkSource := ^Z;
          cc := 0;
          goto 1;
        end;
        if IncludeSw
          then Readln(IncludeF, TnkSource)
          else Readln(InputF,   TnkSource);
        ErrPos := 0;
        Inc(InCount);
        TnkSource := TnkSource + ^A;
        ll := length(TnkSource);
        cc := 0
      end; { if }
   1: Inc(cc);
      ch := TnkSource[cc]
    end; {GetNextCh}


  begin {GetSymbol}
1:
    while ch in [' ',^I] do
      GetNextCh;

    pp := cc;
    case Upcase(ch) of
    '0'..'9':
      begin
        Symbol   := Number;
        IdNumber := '';
        IsHex    := False;
        IsBin    := False;
        repeat
          if Upcase(ch) in ['A'..'F'] then IsHex := True;
          if ch         in ['0', '1'] then IsBin := True;
          IdNumber := IdNumber + Ch;
          GetNextCh
        until Not( Upcase(ch) in ['0'..'9','A'..'F'] );
        k := Length(IdNumber);
        if IsBin and (UpCase(IdNumber[k]) = 'B') then
          begin
            Delete(IdNumber,k,1);
            NumValue := ValueNbase(2,IdNumber);
          end
        else if Upcase(ch) = 'H' then
          begin
            NumValue := ValueNbase(16,IdNumber);
            GetNextCh
          end
        else
          begin
            if IsHex then begin
              Error(erBAD_EXP);
            end
            else begin
              NumValue := ValueNbase(10,IdNumber);
            end;
          end;
      end;

    'A'..'Z':
      begin
        Symbol := Identifier;
        Id := '';
        k  := 0;
        ch := Upcase(ch);
        repeat
          if k < namel then
          begin
            k  := k +1;
            Id := Id + Ch
          end;
          GetNextCh;
          Ch := Upcase(Ch)
        until not( Ch in ['0'..'9', 'A'..'Z'] );
        i := 0;
        j := RwCount;
        repeat
          k := (i+j) div 2;
          if id <= ReservedWord[k].Name
            then j := k-1;
          if id >= ReservedWord[k].Name
            then i := k+1;
        until i>j;
        if i -1 > j
          then Symbol := ReservedWord[k].Value;
      end;

    '"':
      begin
        Symbol := Letter;
        Strings := '';
        GetNextCh;
        while ch <> '"' do
          begin
            Strings := Strings + ch;
            GetNextCh
          end;
        GetNextCh
      end;

    ';':
      begin
        Symbol := Semicolon;
        Strings := '';
        GetNextCh;
        while ch <> ^A do
          begin
            Strings := Strings + Ch;
            GetNextCh
          end
      end;

    '(',  ')',
    '*',  '/',
    '+',  '-',
    '}',  '{',
    ',',  '.',
    '=',  ':',
    '\' :
      begin
	    Symbol := SpecialSymbol[ch];
	    GetNextCh
      end;

    ^Z :
      Symbol := EndofFile;

    ^A :
      begin
        Symbol := EndofLine;
        GetNextCh
      end;

    else
      begin
        Symbol := Badsymbol;
        GetNextCh
      end

   end;

  end; {GetSymbol}


{   TableSetup            }
{                         }
{                         }
Procedure TableSetup;

  Procedure SetSpecialSymbol( a : Char; s : SymbolKind );
    begin
      SpecialSymbol[a] := s;
    end;

  Procedure SetCodeTable( s : SymbolKind; n : TLabelString;
                          b : Byte;       o : OpType);
    begin
      with ReservedWord[RwCount] do
        begin
          Name  := n;
          Value := s;
        end;
      RwCount := RwCount + 1;
      with CodeTable[s] do
        begin
          OpCode      := b;
          OperandType := o
        end
    end;

  begin
    RwCount := 0;

    SetSpecialSymbol('(', RightParen);
    SetSpecialSymbol(')', LeftParen  );
    SetSpecialSymbol(':', Colon     );
    SetSpecialSymbol(';', Semicolon );
    SetSpecialSymbol('+', Plus      );
    SetSpecialSymbol('-', Minus     );
    SetSpecialSymbol('*', Asterisk  );
    SetSpecialSymbol('/', Slush     );
    SetSpecialSymbol('.', Dot       );
    SetSpecialSymbol('\', BackSlush );

    SetCodeTable(ADB,  'ADB' ,  $14, NoType        );
    SetCodeTable(ADCM, 'ADCM',  $C4, NoType        );
    SetCodeTable(ADIA, 'ADIA',  $74, ByteLoad      );
    SetCodeTable(ADIM, 'ADIM',  $70, ByteLoad      );
    SetCodeTable(ADM,  'ADM' ,  $44, NoType        );
    SetCodeTable(ADN,  'ADN' ,  $0C, NoType        );
    SetCodeTable(ADW,  'ADW' ,  $0E, NoType        );
    SetCodeTable(_AND, 'AND' ,  $00, NoType        );
    SetCodeTable(ANIA, 'ANIA',  $64, ByteLoad      );
    SetCodeTable(ANID, 'ANID',  $D4, ByteLoad      );
    SetCodeTable(ANIM, 'ANIM',  $60, ByteLoad      );
    SetCodeTable(ANMA, 'ANMA',  $46, NoType        );
    SetCodeTable(CAL,  'CAL',   $E0, QuickWordLoad );
    SetCodeTable(CALL, 'CALL',  $78, WordLoad      );
    SetCodeTable(CLRA, 'CLRA',  $23, NoType        );
    SetCodeTable(CPIA, 'CPIA',  $67, ByteLoad      );
    SetCodeTable(CPIM, 'CPIM',  $63, ByteLoad      );
    SetCodeTable(CPMA, 'CPMA',  $C7, NoType        );
    SetCodeTable(DB,   'DB'  ,  $00, DefInst       );
    SetCodeTable(DECA, 'DECA',  $43, NoType        );
    SetCodeTable(DECB, 'DECB',  $C3, NoType        );
    SetCodeTable(DECI, 'DECI',  $41, NoType        );
    SetCodeTable(DECJ, 'DECJ',  $C1, NoType        );
    SetCodeTable(DECK, 'DECK',  $49, NoType        );
    SetCodeTable(DECL, 'DECL',  $C9, NoType        );
    SetCodeTable(DECM, 'DECM',  $4B, NoType        );
    SetCodeTable(DECN, 'DECN',  $CB, NoType        );
    SetCodeTable(DECP, 'DECP',  $51, NoType        );
    SetCodeTable(DH,   'DH'  ,  $00, DefInst       );
    SetCodeTable(DM,   'DM'  ,  $00, DefInst       );
    SetCodeTable(DS,   'DS'  ,  $00, DefInst       );
    SetCodeTable(DW,   'DW'  ,  $00, DefInst       );
    SetCodeTable(DX,   'DX',    $05, NoType        );
    SetCodeTable(DXL,  'DXL',   $25, NoType        );
    SetCodeTable(DY,   'DY',    $07, NoType        );
    SetCodeTable(DYS,  'DYS',   $27, NoType        );
    SetCodeTable(_END, 'END',   $00, CtlInst       );
    SetCodeTable(_ENDM,'ENDM',  $00, MacroInst     );
    SetCodeTable(EQU,  'EQU' ,  $00, DefInst       );
    SetCodeTable(EXAB, 'EXAB',  $DA, NoType        );
    SetCodeTable(EXAM, 'EXAM',  $DB, NoType        );
    SetCodeTable(EXB,  'EXB',   $0B, NoType        );
    SetCodeTable(EXBD, 'EXBD',  $1B, NoType        );
    SetCodeTable(EXW,  'EXW',   $09, NoType        );
    SetCodeTable(EXWD, 'EXWD',  $19, NoType        );
    SetCodeTable(FILD, 'FILD',  $1F, NoType        );
    SetCodeTable(FILM, 'FILM',  $1E, NoType        );
    SetCodeTable(HighByte, 'HIGH', $00, Notype     );
    SetCodeTable(INA,  'INA' ,  $4C, NoType        );
    SetCodeTable(INB,  'INB',   $CC, NoType        );
    SetCodeTable(INCA, 'INCA',  $42, NoType        );
    SetCodeTable(INCB, 'INCB',  $C2, NoType        );
    SetCodeTable(INCI, 'INCI',  $40, NoType        );
    SetCodeTable(INCJ, 'INCJ',  $C0, NoType        );
    SetCodeTable(INCK, 'INCK',  $48, NoType        );
    SetCodeTable(INCL, 'INCL',  $C8, NoType        );
    SetCodeTable(INCLUDE,'INCLUDE', $00, CtlInst   );
    SetCodeTable(INCM, 'INCM',  $4A, NoType        );
    SetCodeTable(INCN, 'INCN',  $CA, NoType        );
    SetCodeTable(INCP, 'INCP',  $50, NoType        );
    SetCodeTable(IX,   'IX',    $04, NoType        );
    SetCodeTable(IXL,  'IXL',   $24, NoType        );
    SetCodeTable(IY,   'IY',    $06, NoType        );
    SetCodeTable(IYS,  'IYS',   $26, NoType        );
    SetCodeTable(JP,   'JP',    $79, WordLoad      );
    SetCodeTable(JPC , 'JPC' ,  $7F, WordLoad      );
    SetCodeTable(JPNC, 'JPNC',  $7D, WordLoad      );
    SetCodeTable(JPNZ, 'JPNZ',  $7C, WordLoad      );
    SetCodeTable(JPZ,  'JPZ',   $7E, WordLoad      );
    SetCodeTable(JRCM, 'JRCM',  $3B, Relative      );
    SetCodeTable(JRCP, 'JRCP',  $3A, Relative      );
    SetCodeTable(JRM,  'JRM',   $2D, Relative      );
    SetCodeTable(JRNCM,'JRNCM', $2B, Relative      );
    SetCodeTable(JRNCP,'JRNCP', $2A, Relative      );
    SetCodeTable(JRNZM,'JRNZM', $29, Relative      );
    SetCodeTable(JRNZP,'JRNZP', $28, Relative      );
    SetCodeTable(JRP,  'JRP',   $2C, Relative      );
    SetCodeTable(JRZM, 'JRZM',  $39, Relative      );
    SetCodeTable(JRZP, 'JRZP',  $38, Relative      );
    SetCodeTable(LDD,  'LDD',   $57, NoType        );
    SetCodeTable(LDM,  'LDM',   $59, NoType        );
    SetCodeTable(LDP,  'LDP',   $20, NoType        );
    SetCodeTable(LDPC, 'LDPC',  $56, NoType        );
    SetCodeTable(LDQ,  'LDQ',   $21, NoType        );
    SetCodeTable(LDR,  'LDR',   $22, NoType        );
    SetCodeTable(LEAVE,'LEAVE', $D8, NoType        );
    SetCodeTable(LIA,  'LIA',   $02, ByteLoad      );
    SetCodeTable(LIB,  'LIB',   $03, ByteLoad      );
    SetCodeTable(LIDL, 'LIDL',  $11, ByteLoad      );
    SetCodeTable(LIDP, 'LIDP',  $10, WordLoad      );
    SetCodeTable(LII,  'LII',   $00, ByteLoad      );
    SetCodeTable(LIJ,  'LIJ',   $01, ByteLoad      );
    SetCodeTable(LIP,  'LIP',   $12, ByteLoad      );
    SetCodeTable(LIQ,  'LIQ',   $13, ByteLoad      );
    SetCodeTable(LOOP, 'LOOP',  $2F, Relative      );
    SetCodeTable(LowByte,'LOW', $00, Notype        );
    SetCodeTable(LP,   'LP',    $80, QuickByteLoad );
    SetCodeTable(MACRO,'MACRO', $00, MacroInst     );
    SetCodeTable(MVB,  'MVB',   $0A, Notype        );
    SetCodeTable(MVBD, 'MVBD',  $1A, Notype        );
    SetCodeTable(MVDM, 'MVDM',  $53, Notype        );
    SetCodeTable(MVMD, 'MVMD',  $55, Notype        );
    SetCodeTable(MVMP, 'MVMP',  $54, Notype        );
    SetCodeTable(MVW,  'MVW',   $08, Notype        );
    SetCodeTable(MVWD, 'MVWD',  $18, Notype        );
    SetCodeTable(MVWP, 'MVWP',  $35, Notype        );
    SetCodeTable(NOPT, 'NOPT',  $CE, Notype        );
    SetCodeTable(NOPW, 'NOPW',  $4D, Notype        );
    SetCodeTable(_NOT, 'NOT' ,  $00, Notype        );
    SetCodeTable(_OR , 'OR'  ,  $00, Notype        );
    SetCodeTable(ORG,  'ORG' ,  $00, DefInst       );
    SetCodeTable(ORIA, 'ORIA',  $65, ByteLoad      );
    SetCodeTable(ORID, 'ORID',  $D5, ByteLoad      );
    SetCodeTable(ORIM, 'ORIM',  $61, ByteLoad      );
    SetCodeTable(ORMA, 'ORMA',  $47, Notype        );
    SetCodeTable(OUTA, 'OUTA',  $5D, Notype        );
    SetCodeTable(OUTB, 'OUTB',  $DD, Notype        );
    SetCodeTable(OUTC, 'OUTC',  $DF, Notype        );
    SetCodeTable(OUTF, 'OUTF',  $5F, Notype        );
    SetCodeTable(POP,  'POP',   $5B, Notype        );
    SetCodeTable(PUSH, 'PUSH',  $34, Notype        );
    SetCodeTable(RC,   'RC',    $D1, Notype        );
    SetCodeTable(RTN,  'RTN',   $37, Notype        );
    SetCodeTable(SBB,  'SBB',   $15, Notype        );
    SetCodeTable(SBCM, 'SBCM',  $C5, Notype        );
    SetCodeTable(SBIA, 'SBIA',  $75, ByteLoad      );
    SetCodeTable(SBIM, 'SBIM',  $71, ByteLoad      );
    SetCodeTable(SBM,  'SBM',   $45, Notype        );
    SetCodeTable(SBN,  'SBN',   $0D, Notype        );
    SetCodeTable(SBW,  'SBW',   $0F, Notype        );
    SetCodeTable(SC,   'SC',    $D0, Notype        );
    SetCodeTable(SL,   'SL',    $5A, Notype        );
    SetCodeTable(SLW,  'SLW',   $1D, Notype        );
    SetCodeTable(SR,   'SR',    $D2, Notype        );
    SetCodeTable(SRW,  'SRW',   $1C, Notype        );
    SetCodeTable(STD,  'STD',   $52, Notype        );
    SetCodeTable(STP,  'STP',   $30, Notype        );
    SetCodeTable(STQ,  'STQ',   $31, Notype        );
    SetCodeTable(STR,  'STR',   $32, Notype        );
    SetCodeTable(SWP,  'SWP',   $58, Notype        );
    SetCodeTable(TEST, 'TEST',  $6B, ByteLoad      );
    SetCodeTable(TSIA, 'TSIA',  $66, ByteLoad      );
    SetCodeTable(TSID, 'TSID',  $D6, ByteLoad      );
    SetCodeTable(TSIM, 'TSIM',  $62, ByteLoad      );
    SetCodeTable(TSMA, 'TSMA',  $C6, Notype        );
    SetCodeTable(WAIT, 'WAIT',  $4E, ByteLoad      );
    SetCodeTable(_XOR, 'XOR' ,  $00, Notype        );

  end;

Procedure FileOpen;

  Procedure PutHeader;
    Var Header : Array[0..15] of Byte;
        i      : Byte;
    begin
      for i := 0 to 15
        do Header[i] := HdConst[i];
      Header[5] := Lo(Bottom-Top);
      Header[6] := Hi(Bottom-Top);
      Header[8] := Lo(Top);
      Header[9] := Hi(Top);
      for i := 0 to 15
        do Write(OutputF,Header[i]);
    end;

begin

  Assign(InputF,SourceFile);
  {$I-}
  Reset(InputF);
  {$I+}
  if IOResult <> 0 then
    Fatal('File not found ('+SourceFile+')');

  if PassCount = 2
    then begin

      (* Alloc *)
      GetMem(TnkObjs, Bottom-Top);

      Assign(OutputF,ObjectFile);
      {$I-}
      Rewrite(OutputF);
      {$I+}
      if IOResult <> 0 then
        Fatal('Output fail ('+ObjectFile+')');
      PutHeader;
    end;

end; { FileOpen }

Procedure FileClose;
begin
  Close(InputF);
  if PassCount = 2 then
  begin
    Close(OutputF);
    Dispose(TnkObjs);
  end;
end;

{                            }
{    Initialze               }
{                            }
Procedure Initialize;
  Var i : Byte;

  begin

    IncludeSw    := False;
    IncludeCount := 0;

    cc := 0; ll := 0; Ch := ' ';

    TnkLabel := '';
    InCount  := 0;

    if PassCount = 2
      then begin
        Bottom   := Location;
        Location := Top;
        Exit;
      end;

    Top        := Location;

    LabelCount := 0;
    FactorHead := [ Identifier, Number,   Asterisk,
                    HighByte,   LowByte,  Letter    ];
    BackJumpOp := [ JRCM, JRM, JRNCM, JRNZM, JRZM, LOOP ];
    for i := 0 to 9 do
      Hord[Chr(Ord('0')+i)] := i;
    for i := 0 to 5 do
      Hord[Chr(Ord('A')+i)] := 10 + i;

  end;


Procedure DispLabel;
Var i: TLabelIndex;
begin

  if Not Option.Print then
    Exit;

  Writeln;
  Writeln('CROSS REFERENCE LIST');
  Writeln;

  if LabelCount <> 0 then
  begin
    for i := 1 to LabelCount do
    with LabelTable[i] do
      Writeln('    ',
              Name,
              ' ':8-Length(Name),
              ': ',
              HexStringW(Value) );
    Writeln
  end
end;


{                             }
{  Skips error input.         }
{                             }

Procedure ErrorSkip(Mark: SymbolSet);
begin
  repeat
    GetSymbol;
  until Symbol in Mark + [ EndofFile ];
end;


{                             }
{  Get Label Location.        }
{                             }

Function Loc(Id: TLabelString) : Integer;
Var
  i : TLabelIndex;
begin
  if LabelCount > 0 then
  begin
    for i := 1 to LabelCount do
      if Id = LabelTable[i].Name then
      begin
        Loc := i;
        Exit;
      end;
  end;
  Loc := 0;
end;

{                             }
{  Enter Label-Table.         }
{                             }
Procedure Enter(Id: TLabelString);
begin
  if LabelCount = Lmax then
    Fatal('Too many Label');

  Inc(LabelCount);
  with Labeltable[LabelCount] do
  begin
    Name  := Id;
    Value := Location;
  end;

end;

Procedure SkipComment;
begin
  if Symbol = Semicolon then
  begin
    TnkComment := ';' + Strings;
    GetSymbol;
  end;
end;

Procedure GetLabel;
Label 1;
Var
  i: Word;
begin
  if Symbol <> Identifier then
  begin
    TnkLabel := '';
    Exit;
  end;
  if PassCount = 1 then
  begin
    if Loc(Id) = 0 then
      Enter(Id)
    else begin
      Error(erDUP_LBL); { Duplicate Identifier }
    end
  end;
  TnkLabel := Id;
  LabelPtr := Loc(Id);
  GetSymbol;
  if Symbol = Colon then
  begin
    GetSymbol;
    TnkLabel := TnkLabel + ':'
  end;
  SkipComment;
end;

{                      }
{   Operand process.   }
{                      }

Function Operand : Word;

  Var OperandValue : Word;
      TmpValue     : Word;
      Sy           : SymbolKind;

  Function Term : Word;
    Var TermValue : Word;
        Sy        : SymbolKind;
    Label 1;

    Function Factor : Word;
      Var FactorValue : Word;
          Sy          : SymbolKind;
      Label 1;
      begin
        if Not(Symbol in FactorHead)
          then begin
            Error(erBAD_EXP);
            ErrorSkip([EndofLine]);
            goto 1
          end;
        Sy := Symbol;
        case Sy of
          Asterisk:
              begin
                FactorValue := Location;
                GetSymbol
              end;
          Number:
              begin
                if NumValue > $FFFF then
                begin
                  NumValue := NumValue And $FFFF;
                end;
                FactorValue := NumValue;
                GetSymbol
              end;
          Identifier:
              begin
                if PassCount = 1
                  then FactorValue := 0
                  else begin
                    if Loc(id) > 0 then
                      FactorValue := LabelTable[Loc(id)].Value
                    else begin
                      Error(erUDF_LBL);
                      GetSymbol;
                      goto 1
                    end
                  end;
                GetSymbol
              end;
          HighByte,
           LowByte:
              begin
                GetSymbol;
                if Symbol <> RightParen
                  then begin
                    Error(erSTX_ERR);
                    ErrorSkip([EndOfLine]);
                    goto 1
                  end;
                GetSymbol;
                FactorValue := Operand;
                if Symbol <> LeftParen
                  then begin
                    Error(erSTX_ERR);
                    ErrorSkip([EndofLine]);
                    goto 1;
                  end;
                if Sy = HighByte
                  then FactorValue := FactorValue div 256
                  else FactorValue := FactorValue mod 256;
                GetSymbol
              end;
          Letter:
              begin
                FactorValue := Ord(Strings[1]);
                OprStr      := Strings;
                GetSymbol
              end;
        end;
      1:
        Factor := FactorValue;
      end; { Factor }

    begin { Term }
      TermValue := Factor;
      while Symbol in [Plus,Minus]
        do begin
           Sy := Symbol;
           GetSymbol;
           {$R-}{$Q-}
           case Sy of
             Plus  : TermValue := TermValue + Factor;
             Minus : TermValue := TermValue - Factor;
           end
           {$R+}{$Q+}
        end;
      Term := TermValue
    end;

  begin { Operand }
    OperandValue := Term;
    while Symbol in [Asterisk, Slush, BackSlush]
      do begin
        Sy := Symbol;
        GetSymbol;
        case Sy of
          Asterisk:
                    OperandValue := OperandValue  *  Term;
          Slush,
          BackSlush:
                    begin
                      TmpValue := Term;
                      if TmpValue <> 0 then
                        case Sy of
                          Slush     : OperandValue := OperandValue div TmpValue;
                          BackSlush : OperandValue := OperandValue mod TmpValue
                        end
                      else begin
                        OperandValue := 0;
                        Error(erBAD_EXP);
                      end
                    end
        end
      end;
    Operand := OperandValue
  end; { Operand }

{                        }
{     Get Op Code        }
{                        }

Procedure GetOpCode;

  Var   OpLength  : Word;

        OpcValue  : Byte;
        OpcType   : SymbolKind;

        OprValue,
        TmpValue  : Word;

        OprType   : OpType;

        Offset    : Word;

        OprBgnptr,
        OprEndptr : Byte;

  Procedure MakeObject;
    Var i,j   : Byte;
        wkstr : TLabelString;

    Procedure WriteOp(B: Byte);
      begin
        TnkList := TnkList+HexStringB(B);
        Write(OutputF,B);
      end;

    begin {MakeObject}

      if PassCount = 1 then Exit;

      case OprType of
        Notype       :
          WriteOp(OpcValue);

        QuickByteLoad:
          begin
            OpcValue := OpcValue or Lo(OprValue);
            WriteOp(OpcValue);
          end;

        QuickWordLoad:
          begin
            OpcValue := OpcValue or Hi(OprValue);
            WriteOp(OpcValue);
            WriteOp(Lo(OprValue));
          end;

        ByteLoad:
          begin
            WriteOp(OpcValue);
            WriteOp(Lo(OprValue));
          end;

        WordLoad:
          begin
            WriteOp(OpcValue);
            WriteOp(Hi(OprValue));
            WriteOp(Lo(OprValue));
          end;

        Relative:
          begin
            WriteOp(OpcValue);
            if OpcType in BackJumpOp then
            begin
              if Location >= OprValue then
                Offset := Location - OprValue +1
              else begin
                Error(erBAD_EXP);
                Exit;
              end
            end
            else begin
              if OprValue >= Location then
                Offset := OprValue - Location -1
              else begin
                Error(erBAD_EXP);
                Exit;
              end
            end;
            if Offset > $FF then
            begin
              Error(erBAD_EXP);
              Exit;
            end;
            WriteOp(Lo(Offset))
          end;

        DefInst:
          begin
            case Opctype of
              DB: begin
                    WriteOp(Lo(OprValue));
                  end;
              DS: begin
                    if OprValue <> 0
                      then
                      for i := 1 to OprValue
                        do WriteOp(0)
                  end;
              DW: begin
                    WriteOp(hi(OprValue));
                    WriteOp(lo(OprValue));
                  end;
              DH: begin
                    j := 1;
                    for i := 1 to Oplength
                      do begin
                        WkStr := Copy(OprStr,j,2);
                        Writeop(ValueNbase(16,WkStr));
                        j := j + 2
                      end
                  end;
              DM: begin
                    for i := 1 to OpLength do
                      WriteOp(Ord(OprStr[i]))
                  end
            end

          end;

      end;

    end; {MakeObject}

  begin {GetOpCode}

    if Symbol = EndOfLine then
      Exit;

    if Not(Symbol in [ADB..WAIT, EQU..DH, ORG])
      then begin
        Error(erSTX_ERR);  { Syntax Error. }
        Exit;
      end;

    OpcType := Symbol;
    TnkOp   := Id;
    with CodeTable[Symbol]
      do begin
        OpcValue := OpCode;
        OprType  := OperandType;
      end;
    case OprType of
      Notype         : OpLength := 1;

      QuickByteLoad  : OpLength := 1;

      QuickWordLoad,
      ByteLoad,
      Relative       :
        OpLength := 2;

      WordLoad       :
        OpLength := 3;

      DefInst        :
        OpLength := 0;

      CtlInst        :
        OpLength := 0;

      MacroInst      :
        OpLength := 0
    end;

    GetSymbol;
    if OprType = Notype
      then TnkOperand := ''
      else begin
        TnkOperand := TnkSource;
        OprBgnPtr  := pp;
        OprValue   := Operand;
        OprEndPtr  := pp;
        TnkOperand := Copy(TnkOperand,OprBgnPtr,OprEndPtr-OprBgnPtr);
      end;
    case OprType of
    DefInst:
      case OpcType of
        EQU: begin
               OpLength := 0;
               if Length(TnkLabel) <> 0 then
                  LabelTable[LabelPtr].Value := OprValue
             end;
         DB: OpLength := 1;
         DS: OpLength := OprValue;
         DW: OpLength := 2;
         DH: OpLength := Length(OprStr) div 2;
         DM: OpLength := Length(OprStr);
        ORG: begin
               OpLength := 0;
               Location := OprValue;
               Top      := Location;
             end;
      end;
    QuickByteLoad:
      if OprValue >= 64 then
      begin
        Error(erOPR_OVR);
        Exit;
      end;
    end;
    MakeObject;
    Location := Location + OpLength;
  end; {GetOpCode}

Procedure DispList;

type
  TParamRec = record
    PObj   : ^String;
    PLabel : ^String;
    POp    : ^String;
    POpr   : ^String
  end;


Var
  LineBuff: String;
  SrcRec  : TParamRec;

begin

  if PassCount <> 2 then
    Exit;

  if Not Option.Print then
    Exit;

  with SrcRec do
  begin
    PObj   := @TnkList;
    PLabel := @TnkLabel;
    POp    := @TnkOp;
    POpr   := @TnkOperand;
  end;

  FormatStr(LineBuff, '%-25s %-16s%-5s %-30s', SrcRec);

  Writeln(LineBuff);

end; {DispList}

{         Pass          }
{                       }
Procedure Pass(P: TPassCount);

  Procedure OnelineAssemble;
    begin

      if PassCount = 2 then
      begin
        TnkList    := HexStringW(Location) + ':';
        TnkLabel   := '';
        TnkOp      := '';
        TnkOperand := '';
      end;

      while Symbol in [EndofLine, Semicolon] do
        GetSymbol;

      case Symbol of
        EndofFile :
          Exit;

        Identifier,
        ADB..WAIT,
        EQU..DH,
        ORG      :
          begin
            GetLabel;
            GetOpCode;
            DispList;
          end;

        _END     :
          begin
            ErrorSkip([EndOfFile]);
          end;

        INCLUDE  :
          begin
            if IncludeSw
              then begin
                Error(erCNT_INC);  { Cannot include }
                Exit;
              end;
            GetSymbol;
            if Symbol <> Letter
              then begin
                Error(erCNT_INC);
                Exit;
              end
            else begin
              IncludeFile := Strings;
              Inc(IncludeCount);
              IncTable[IncludeCount] := IncludeFile;
              InCountSv   := InCount;
              InCount     := 0;
              {$I-}
              Assign(IncludeF,IncludeFile);
              Reset(IncludeF);
              {$I+}
              if IoResult <> 0
                then begin
                  Error(erSTX_ERR);
                  Exit;
                end;
              IncludeSw := True;
            end
          end;

        MACRO:
          begin
          end;


        else begin
          Error(erSTX_ERR);
          ErrorSkip([EndOfLine]);
        end
      end;
    end; { OnelineAssemble }

  begin  { Pass }
    PassCount := P;
    Initialize;
    FileOpen;
    GetSymbol;
    while Symbol <> EndofFile do
      OnelineAssemble;
    FileClose;
  end;


{                         }
{  Display ERROR-MESSAGE  }
{                         }
{                         }
Procedure DispErrMsg;
  Var i : byte;

  begin
    Writeln(' Total errors. = ',ErrorCount);
    for i := 1 to ErrorCount do
      with Errtable[i] do
        begin
          if FileNo <> 0
            then Write(IncTable[FileNo])
            else Write(SourceFile);
          Writeln(' Line  ',  Cnt:3,
                  ': ',       ErrMsg[TErrOrd(erno)]);
        end
  end;

Procedure ParamScan;
Var i: Integer;
    s: String;
begin

  if ParamCount = 0 then
    begin
      Option.Help := True;
      Exit;
    end;

  Option.Help  := False;
  Option.Print := False;
  Option.Format:= BIN_FORMAT;

  s := ParamStr(1);
  SourceFile := '';

  for i := 1 to length(s) do
    SourceFile := SourceFile + UpCase(s[i]);

  if Pos('.',SourceFile) = 0 then
    SourceFile := SourceFile + '.ASC';

  ObjectFile := Copy(SourceFile,1,length(SourceFile)-3) + 'OSC';

  for i := 2 to ParamCount do
    begin
      s := ParamStr(i);
      if (s = '/L') or (s = '/l') then Option.Print := True;
      if (s = '/H') or (s = '/h') then Option.Format:= HEX_FORMAT;
    end;

end;

Procedure Usage;
begin
  Writeln('usage: TNKA source_filename [options]');
  Writeln(' options');
  Writeln('   /l  List.');
  Writeln('   /h  Output .HEX file.');
end;


begin { Main }

  Writeln(FirstMsg);
  ParamScan;
  if Option.Help then
    begin
      Usage;
      ExitCode := 2;
      Exit;
    end;
  Location := $9000;
  ErrorCount := 0;
  TableSetup;
  Pass(1);
  if ErrorCount = 0 then
    Pass(2);
  if ErrorCount > 0 then
    begin
      DispErrMsg;
      ExitCode := 1;
    end
    else begin
      {DispLabel;}
      ExitCode := 0;
    end;
  Writeln(SecondMsg);
  
end.


