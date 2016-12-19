{
Unidad que define al objeto TEvalExpres, que permite evaluar el resultado de una
expresión aritmética en un cadena de una línea.
Reoonoce las variables. Estas deben crearse con TEvalExpres.AisgVariable().

                                                         Por Tito Hinostroza 17/12/2016
}
unit EvalExpres;
{$mode objfpc}{$H+}
interface
uses  Classes, SysUtils, math, Forms, LCLType;
Const
  FIN_CON = #0;    //Fin de contexto

Type
  { Texpre }
  //Tipo expresión. Se usa para manejo de evaluación aritmética.
  Texpre = record//Tipo expresión
    valNum: Single;    //Valor numérico de la expresión
    CadError: string;
  End;

  { TContexto }
  {Define al objeto contexto, que es una abstracción para leer datos de entrada.}
  TContexto = class
    col      : Integer;  //columna actual
    lin      : string;   //Línea de texto
    constructor Create;
    destructor Destroy; override;
    //Métodos de lectura
    Function IniCont:Boolean;
    Function FinCont:Boolean;
    Function VerCar:Char;
    Function CogCar:Char;
    Function VerCarSig: Char;
    Function CapBlancos:Boolean;
    //Métodos de escritura
    procedure CurPosIni;
    procedure CurPosFin;
  End;

  //Define a una variable.
  //Se define como registro clásico, para optimizar la velocidad.
  TEVar= record
    nomb: string[12];   //Nombre de la variable
    valor: Double;      //Valor de la variable
  end;

  { TEvalExpres }
  {Objeto evaluador de expresiones.}
  TEvalExpres = class
  public
    cEnt : TContexto;   //referencia al contexto de entrada actual
    vars : array of TEVar;  //Se puede hacer estático, si se quiere ganar velocidad
    nVars: integer;     //Número de variables
    //rutinas basicas de lectura
    Function VerCarN(numcar:Integer): String;
    function Capturar(cap: String): Boolean;
    function CogCarERR(car: char): Boolean;
    //Rutinas avanzadas de lectura
    function CogNumero(var n:Single):boolean;
    function CogIdentif(var s: string):boolean;
    function cogOperador: String;           //coge operador
    function jerOp(oper: String): Integer;  //jerarquía de operador
    function Evaluar(Op1: Texpre; opr: String; Op2: Texpre): Texpre;
    function CogOperando: Texpre;
    function CogExpresion(jerar: Integer): Texpre;
    function CogExpresionPar: Texpre;
    function AsigVariable(const VarName: string; value: Double): integer;
    function EvaluarLinea(lin: string): Texpre;
  public  //Campos para manejo de error
    ErrorCol : integer;   //número de columna del error
    ErrorStr : string;    //cadena de error
    procedure GenError(msje: String; col: integer=-1);
  public  //Inicialización
    procedure Iniciar(txt: string);   //Prepara la secuencia de preprocesamiento
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TContexto }
//********************************************************************************
//Funciones Básicas para administración de los Contextos
//********************************************************************************
constructor TContexto.Create;
begin
  CurPosFin;   //inicia fil y col
end;
destructor TContexto.Destroy;
begin
  inherited Destroy;
end;
function TContexto.IniCont: Boolean;
//Devuelve verdadero si se está al inicio del Contexto (columna 1)
begin
  Result := (col = 1);
end;
function TContexto.FinCont: Boolean;
//Devuelve verdadero si se ha pasado del final del Contexto actual
begin
  Result := (col >= Length(lin) + 1);
end;
function TContexto.VerCar: Char;
//Devuelve el caracter actual
//Si no hay texto en el Contexto actual o si se ha llegado al final del
//texto, devuelve FIN_CON.
begin
  if FinCont Then exit(FIN_CON);
  Result := lin[col];
end;
function TContexto.CogCar: Char;
//Lee un caracter del contexto y avanza el cursor una posición.
//Si no hay texto en el Contexto actual o si se ha llegado al final del
//texto, devuelve FIN_CON.
begin
  if FinCont Then exit(FIN_CON);
  Result := lin[col];
  inc(col);
end;
function TContexto.VerCarSig: Char;
//Devuelve el catacter siguiente al actual.
//Si no hay caracter siguiente, devuelve caracter nulo.
begin
  if FinCont Then exit(#0);
  Result := lin[col+1];
end;
function TContexto.CapBlancos: Boolean;
//Coge los blancos iniciales del contexto de entrada.
//Si no encuentra algun blanco al inicio, devuelve falso
begin
  Result := False;
  while not FinCont and (VerCar in [' ', #9]) do
    CogCar;
end;
procedure TContexto.CurPosIni;
//Mueve la posición al inicio del contenido.
begin
  col := 1;   //posiciona al inicio
end;
procedure TContexto.CurPosFin;
//Mueve la posición al final del contenido.
begin
  col := length(lin)+1;   //posiciona al final
end;

{ TEvalExpres }
function TEvalExpres.VerCarN(numcar: Integer): String;
//Devuelve los N caracteres a partir de la posición actual, del Contexto actual.
//Si no hay texto en el Contexto actual o si se ha llegado al final del
//texto, devuelve FIN_CON.
begin
  if cEnt.FinCont Then Exit(FIN_CON);
  Result := copy(cEnt.lin, cEnt.col, numcar);
End;
function TEvalExpres.Capturar(cap: String): Boolean;
{Coge la cadena dada ignorando los blancos iniciales.}
Var i:Integer;
begin
  Result := False;
  cEnt.CapBlancos;     //quita blancos iniciales
  i := 1;
  while Not cEnt.FinCont And (i <= Length(cap)) do begin
    if cEnt.VerCar = cap[i] then begin
      cEnt.CogCar;
      i := i + 1;
    end else begin
      exit;     //fallo en algun caracter
    end;
  end;
  if i > Length(cap) then begin   //encontró toda la cadena
    Result := true;
  end;
End;
function TEvalExpres.CogCarERR(car: char): Boolean;
{Coge el caracter indicado. Si no lo encuentra genera error y devuelve FALSE.}
begin
  if cEnt.VerCar=car then begin
    //Es el caracter buscado
    cEnt.CogCar;
    exit(true);
  end else begin
    GenError('Error en expresión. Se esperaba "'+ car +'"');
    exit(false);
  end;
end;
function TEvalExpres.CogNumero(var n: Single): boolean;
{Veririfca si lo que sigues es un número y de ser así, intenta tomarlo.
Puede geenrar error al convertir el número}
Var car:char;
    temp:String;
begin
    car := cEnt.VerCar;
    If Not (car in ['0'..'9','.','-']) Then      //primer caracter no valido
       exit(false);        //no es numero
    if (car in ['.','-']) and not (cEnt.VerCarSig in ['0'..'9']) then
       exit(false);    //no es válido
    temp := cEnt.CogCar;   //acumula primer dígito
    //busca hasta encontar fin de identificador
    While cEnt.VerCar in ['0'..'9','.'] do begin
      car := cEnt.CogCar;     //toma el caracter
      temp += car;     //acumula
    end;
    //se llego al final del número
    if not TryStrToFloat(temp, n) then begin
      GenError('Error en número: ' + temp, cEnt.col);
    end;
    Result := true;  //indica que hubo número
end;
function TEvalExpres.CogIdentif(var s: string): boolean;
{Coge un identificador, que debe corresponder a una variable.}
begin
  if not (cEnt.VerCar in ['a'..'z','A'..'Z']) then   //primer caracter no valido
    exit(false);        //no es constante cadena
  s := '';         //inicia para acumular
  //Busca hasta encontar fin de identificador
  while not cEnt.FinCont and (cEnt.VerCar in ['a'..'z','A'..'Z']) do begin
    s += cEnt.CogCar;
  end;
  Result := true;    //indica que se encontró identificador
end;
function TEvalExpres.cogOperador: String;
{Coge un operador en la posición del contexto actual. Si no encuentra
 devuelve cadena vacía y no coge caracteres, salvo espacios iniciales.}
begin
  cogOperador := '';
  cEnt.CapBlancos;     //quita blancos iniciales
  Case cEnt.VerCar of //completa con operador de más caracteres
  '+': begin
         Result := cEnt.CogCar;
        end;
  '-': begin
         Result := cEnt.CogCar;
      end;
  '*': begin
        Result := cEnt.CogCar;
      end;
  '/': begin
        Result := cEnt.CogCar;
      end;
  '\': begin
        Result := cEnt.CogCar;
      end;
  '%': begin
        Result := cEnt.CogCar;
      end;
  '^': begin
        Result := cEnt.CogCar;
      end;
  End;
End;
function TEvalExpres.jerOp(oper: String): Integer;
//Devuelve la jerarquía de un operador ver documentación técnica.
begin
    case oper of
    '+', '-': jerOp := 5;
    '*', '/', '\', '%': jerOp := 6;
    '^': jerOp := 8;
    else jerOp := 0;
    end;
End;
function TEvalExpres.Evaluar(Op1: Texpre; opr: String; Op2: Texpre): Texpre;
//Devuelve el resultado y tipo de una operación
begin
    ErrorStr:='';
    Case opr of
    '': begin     //Sin operador. Y se supone sin Op2
          //no hay nada que hacer, ya está en la pila
          Result := Op1;
        end;
    '+': begin
          Result.valNum := Op1.valNum + Op2.valNum;  //Fuerza a Result.tip := TIP_NUM
         end;
    '-': begin
          Result.valNum := Op1.valNum - Op2.valNum;
         end;
    '*': begin
          Result.valNum := Op1.valNum * Op2.valNum;
         end;
    '/': begin
          if Op2.valNum = 0 Then
              GenError('No se puede dividir por cero.')
          else begin   //error
              Result.valNum := Op1.valNum / Op2.valNum;
          End;
         end;
    '\': begin
          if Op2.valNum = 0 Then
              GenError('No se puede dividir por cero.')
          else begin   //error
              Result.valNum := round(Op1.valNum) div round(Op2.valNum);
          end;
         end;
    '%': begin
          if Op2.valNum = 0 Then
              GenError('No se puede dividir por cero.')
          else begin   //error
              Result.valNum := round(Op1.valNum) mod round(Op2.valNum);
          end;
         end;
    '^': begin
          if (Op2.valNum = 0) And (Op2.valNum = 0) Then
              GenError('No se puede Result 0^0')
          else begin   //error
              Result.valNum := power(Op1.valNum, Op2.valNum);
          end;
         end;
    else begin
        GenError('No se reconoce operador: ' + opr, cEnt.col);
        Exit;
         End;
    end;
End;
function TEvalExpres.CogOperando: Texpre;
{Coge un operando en la posición actual del contenido. Si no enceuntra
el operando o es erróneo, genera Error.}
var
  cad : String;
  num : single;
  exp : Texpre;
  i: Integer;
begin
  cEnt.CapBlancos;   //quita blancos iniciales
  if cEnt.FinCont then begin
    exit;
  end;
  if CogNumero(num) then begin
    if ErrorStr<>'' then exit;  //pudo haber error en número
    Result.valNum := num;   //fija tipo a número
  end else if CogIdentif(cad) then begin
    //Es un identificador.
    //Busca si es una variable
    for i:=0 to nVars-1 do begin
      if vars[i].nomb = cad then begin
        Result.valNum := vars[i].valor;
        exit;
      end;
    end;
    //No es variable, busca si es función
    case cad of
    'abs': begin
      exp := CogExpresionPar;
      if ErrorStr<>'' then exit;
      Result.valNum := abs(exp.valNum);
      exit;  //sale sin error
    end;
    'sgn': begin
      exp := CogExpresionPar;
      if ErrorStr<>'' then exit;
      Result.valNum := Sign(exp.valNum);
      exit;  //sale sin error
    end;
    'sgn2': begin  //variación de la función Sgn()
      exp := CogExpresionPar;
      if ErrorStr<>'' then exit;
      if exp.valNum<0 then Result.valNum := 0
      else Result.valNum := exp.valNum;
      exit;  //sale sin error
    end;
    'sen': begin
      exp := CogExpresionPar;
      if ErrorStr<>'' then exit;
      Result.valNum := sin(exp.valNum);
      exit;  //sale sin error
    end;
    'cos': begin
      exp := CogExpresionPar;
      if ErrorStr<>'' then exit;
      Result.valNum := cos(exp.valNum);
      exit;  //sale sin error
    end;
    'tan': begin
      exp := CogExpresionPar;
      if ErrorStr<>'' then exit;
      Result.valNum := tan(exp.valNum);
      exit;  //sale sin error
    end;
    end;
    //No es variable ni función.
    GenError('Función o variable desconocida: '+cad, cEnt.col);
  end else If cEnt.VerCar = '(' Then begin
    Result := CogExpresionPar;
    exit;  //Puede salir con error
  end else begin
    //Debe ser otra cosa
    exit;  //no devuelve nada
  end;
end;
function TEvalExpres.CogExpresion(jerar: Integer): Texpre;
//Toma una expresión completa, en la posición actual del contenido
//Si no encuentra una expresión, genera error
var Op1, Op2 : Texpre;
    opr, opr2 : String;
    jerOpr, jerOpr2: Integer;
    pos1, pos2 : integer;
begin
    cEnt.CapBlancos;  //quita blancos iniciales
    Op1 := CogOperando;  //error
    if ErrorStr<>'' then exit;
    opr := cogOperador;
    if opr = '' Then begin
      Result := Op1;
      Exit
    End;
    jerOpr := jerOp(opr);     //Hay operador, tomar su jerarquía
    //-------------------------- ¿Delimitada por jerarquía? ---------------------
    if jerOpr <= jerar then begin  //es menor que la que sigue, expres.
      Result := Op1;  //solo devuelve el único operando que leyó
      Exit;
    End;
    while opr <> '' do begin
        pos1 := cEnt.col;    //Guarda por si lo necesita
        Op2 := CogOperando;
        if ErrorStr<>'' then exit;
        pos2 := cEnt.col;    //Guarda por si lo necesita
        opr2 := cogOperador;
        If opr2 <> '' Then begin  //Hay otro operador
            jerOpr2 := jerOp(opr2);
            //¿Delimitado por jerarquía de operador?
            If jerOpr2 <= jerar Then begin  //sigue uno de menor jerarquía, hay que salir
                cEnt.col := pos2;   //antes de coger el operador
                Result := Evaluar(Op1, opr, Op2);
                Exit;
            End;
            If jerOpr2 > jerOpr Then begin    //y es de mayor jerarquía, retrocede
                cEnt.col:= pos1;        //retrocede
                Op2 := CogExpresion(jerOpr);        //evalua primero
                opr2 := cogOperador;    //actualiza el siguiente operador
            End;
        End;

        Op1 := Evaluar(Op1, opr, Op2);    //evalua resultado
        if ErrorStr<>'' then exit;
        opr := opr2;
        jerOpr := jerOp(opr);    //actualiza operador anterior
    end;
    Result := Op1;
end;
function TEvalExpres.CogExpresionPar: Texpre;
{Coge una expresión que debe estar encerrada entre paréntesis. Puede genera error}
begin
  if not CogCarERR('(') then exit;  //sale con error
  Result := CogExpresion(0);
  if ErrorStr<>'' then exit;  //sale con error
  cEnt.CapBlancos;
  if not CogCarERR(')') then exit;  //sale con error
end;
function TEvalExpres.AsigVariable(const VarName: string; value: Double): integer;
{Asigna un valor numérico a una variable. Si no existe la crea.
Devuelve el índice de la variable en el arreglo vasr[].}
var
  i: Integer;
begin
  //Busca variable
  for i:=0 to nVars-1 do begin
    if vars[i].nomb = VarName then begin
      vars[i].valor := value;
      exit(i);
    end;
  end;
  //No se encontró, se debe crear
  inc(nVars);
  setlength(vars, nVars);
  Result := nVars-1;
  vars[Result].nomb := VarName;
  vars[Result].valor := value;
end;
function TEvalExpres.EvaluarLinea(lin: string): Texpre;
{Evalúa la expresión que está contenida en "lin"}
begin
  ErrorStr:='';          //Inicia bandera de error
  Iniciar(lin);   //Inicia cadena
  Result := CogExpresion(0);  //coge expresión
  if ErrorStr<>'' then exit;  //puede generar error
  //Verifica si terminó de procesar toda la línea
  if not cEnt.FinCont then
    GenError('Error de sintaxis.');
end;
procedure TEvalExpres.GenError(msje: String; col: integer = -1);
begin
  ErrorStr := msje;
  if col = -1 then ErrorCol := cEnt.col  //por dfeecto
  else ErrorCol := col;
end;
constructor TEvalExpres.Create;
begin
  cEnt := TContexto.Create;   //Crea un contexto
  nVars := 0;
  setlength(vars, nVars);
end;
destructor TEvalExpres.Destroy;
begin
  cEnt.Destroy;
  inherited;
end;
procedure TEvalExpres.Iniciar(txt: string);
//Inicia la maquinaria de manejo de Contextos
begin
  cEnt.lin := txt;
  cEnt.CurPosIni;       //posiciona al inicio
end;

end.

