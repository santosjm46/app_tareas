import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiUrl = 'https://script.google.com/macros/s/AKfycbyn0_uxfmbkyw7LPQif0Y2p1GMf-VgoPk12BHwCEjWxpZr_rr0th9mAIoux6WXio4ji/exec';

const patioLocations=['CAJA FERROVIARIA','CENTRO','CHASQUIPAMPA','HUAYLLANI','INCALLOJETA','INTEGRADORA','IRPAVI','LA PORTADA','SUB ALCALDÍA M.','VILLA SALOMÉ'];
const baNumbers=['002','003','004','005','006','007','008','009','010','011','012','013','014','015','018','019','021','022','023','024','026','028','029','030','031','033','034','035','037','038','039','040','041','044','045','046','047','049','050','051','052','053','054','055','056','057','058','060','061','062','063','064','065','066','068','071','073','074','075','076','077','078','080','081','082','084','087','088','089','090','091','092','093','094','095','096','097','099','100','103','104','108','109','110','111','112','114','116','117','118','120','121','122','123','124','127','128','132','133','134','135','136','137','138','139','142','145','173'];
const bsNumbers=['001','002','003','004','005','006','007','008','009','010','011','012','013','014','015','016','017','018','019','020','021','022','023','024','025','026','027','028','029','030','031','032','033','034','035','036','037','038','039'];
const barNumbers=['001','016','017','020','025','027','032','036','042','043','048','059','067','069','070','072','079','083','085','086','098','101','102','105','106','107','113','115','119','125','126','129','130','131','140','141','143','144','146','147','148','149','150','151','152','153','154','155','156','157','158','159','160','161','162','163','164','165','166','167','168','169','170','171','172','174'];
final busCodes=[...baNumbers.map((n)=>'BA-$n'),...bsNumbers.map((n)=>'BS-$n'),...barNumbers.map((n)=>'BAR-$n')];

void main() => runApp(const UmaApp());

class UmaApp extends StatelessWidget {
  const UmaApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner:false,title:'UMA Trabajos',theme:ThemeData.dark().copyWith(scaffoldBackgroundColor:const Color(0xff12100b),colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xffd69b25),brightness:Brightness.dark),inputDecorationTheme:const InputDecorationTheme(filled:true,fillColor:Color(0xff211e17),border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(12))))),home:const SessionGate());
}

class SessionStore{
 static Future<void> save(String token,Map<String,dynamic> profile)async{final p=await SharedPreferences.getInstance();await p.setString('session_token',token);await p.setString('session_profile',jsonEncode(profile));}
 static Future<void> clear()async{final p=await SharedPreferences.getInstance();await p.remove('session_token');await p.remove('session_profile');}
}

class SessionGate extends StatefulWidget{const SessionGate({super.key});@override State<SessionGate>createState()=>_SessionGateState();}
class _SessionGateState extends State<SessionGate>{Widget? page;
 @override void initState(){super.initState();restore();}
 Future<void> restore()async{try{final p=await SharedPreferences.getInstance();final token=p.getString('session_token'),raw=p.getString('session_profile');if(token!=null&&raw!=null){final test=await api({'action':'getCatalogs','token':token});if(test['ok']==true){page=HomePage(token:token,profile:Map<String,dynamic>.from(jsonDecode(raw)));}else{await SessionStore.clear();page=const LoginPage();}}else page=const LoginPage();}catch(_){page=const LoginPage();}if(mounted)setState((){});}
 @override Widget build(BuildContext context)=>page??Scaffold(body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Image.asset('assets/uma_icon_gold.png',width:110,height:110),const SizedBox(height:18),const CircularProgressIndicator()])));
}

Future<Map<String,dynamic>> api(Map<String,dynamic> body) async {
  final client=HttpClient();
  final uri=Uri.parse(apiUrl).replace(queryParameters:{'payload':jsonEncode(body)});
  final req=await client.getUrl(uri);
  final res=await req.close();
  final text=await utf8.decodeStream(res);
  client.close();
  if(text.trimLeft().startsWith('<')){
    throw const FormatException('El servidor devolvió una página web en lugar de datos. Revisa el acceso de la implementación de Apps Script.');
  }
  return jsonDecode(text) as Map<String,dynamic>;
}

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage>{
  final user=TextEditingController(),pass=TextEditingController(text:'123456'); bool busy=false; String error='';
  Future<void> login() async { setState(()=>busy=true); try{final r=await api({'action':'login','username':user.text.trim(),'password':pass.text}); if(r['ok']!=true) throw Exception(r['error']); final d=r['data']; if(d is! Map || d['token']==null || d['user'] is! Map) throw Exception('Apps Script todavía usa la versión anterior. Crea una nueva versión en Administrar implementaciones.'); if(!mounted)return;final token=d['token'].toString();final profile=Map<String,dynamic>.from(d['user']);if(d['mustChangePassword']!=true)await SessionStore.save(token,profile);if(!mounted)return;Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>d['mustChangePassword']==true?ChangePasswordPage(token:token,profile:profile,requiredChange:true):HomePage(token:token,profile:profile)));}catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Card(color:const Color(0xff1d1a13),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),child:Padding(padding:const EdgeInsets.all(28),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const Icon(Icons.engineering,size:68,color:Color(0xffe7b653)),const SizedBox(height:16),const Text('SETRAM',textAlign:TextAlign.center,style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Color(0xffe7b653),letterSpacing:3)),const SizedBox(height:28),const Text('Registro diario\nde trabajos',style:TextStyle(fontSize:34,fontWeight:FontWeight.bold)),const SizedBox(height:24),TextField(controller:user,decoration:const InputDecoration(labelText:'Usuario',prefixIcon:Icon(Icons.person))),const SizedBox(height:14),TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Contraseña',prefixIcon:Icon(Icons.lock))),if(error.isNotEmpty)Padding(padding:const EdgeInsets.only(top:12),child:Text(error,style:const TextStyle(color:Colors.redAccent))),const SizedBox(height:20),FilledButton(onPressed:busy?null:login,style:FilledButton.styleFrom(padding:const EdgeInsets.all(16),backgroundColor:const Color(0xffdfa634),foregroundColor:Colors.black),child:busy?const CircularProgressIndicator():const Text('INGRESAR',style:TextStyle(fontWeight:FontWeight.bold))) ]))))))));
}

class ChangePasswordPage extends StatefulWidget{final String token;final Map<String,dynamic> profile;final bool requiredChange;const ChangePasswordPage({super.key,required this.token,required this.profile,this.requiredChange=false});@override State<ChangePasswordPage>createState()=>_ChangePasswordPageState();}
class _ChangePasswordPageState extends State<ChangePasswordPage>{final password=TextEditingController(),confirm=TextEditingController();bool busy=false,show=false;String error='';
 Future<void> save()async{final value=password.text;if(value.length<6){setState(()=>error='La contraseña debe tener al menos 6 caracteres');return;}if(value=='123456'){setState(()=>error='Elige una contraseña diferente a la inicial');return;}if(value!=confirm.text){setState(()=>error='Las contraseñas no coinciden');return;}setState((){busy=true;error='';});try{final r=await api({'action':'changePassword','token':widget.token,'newPassword':value});if(r['ok']!=true)throw Exception(r['error']);await SessionStore.save(widget.token,widget.profile);if(!mounted)return;Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>HomePage(token:widget.token,profile:widget.profile)),(_)=>false);}catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context)=>PopScope(canPop:!widget.requiredChange,child:Scaffold(appBar:AppBar(automaticallyImplyLeading:!widget.requiredChange,title:Text(widget.requiredChange?'Cambio obligatorio':'Cambiar contraseña')),body:ListView(padding:const EdgeInsets.all(24),children:[Icon(widget.requiredChange?Icons.security:Icons.password,size:72,color:const Color(0xffe7b653)),const SizedBox(height:18),Text(widget.requiredChange?'Por seguridad debes reemplazar la contraseña temporal 123456 antes de continuar.':'Ingresa tu nueva contraseña.',textAlign:TextAlign.center,style:const TextStyle(fontSize:18)),const SizedBox(height:24),TextField(controller:password,obscureText:!show,decoration:const InputDecoration(labelText:'Nueva contraseña',prefixIcon:Icon(Icons.lock))),const SizedBox(height:12),TextField(controller:confirm,obscureText:!show,decoration:const InputDecoration(labelText:'Confirmar contraseña',prefixIcon:Icon(Icons.lock_outline))),CheckboxListTile(value:show,onChanged:(v)=>setState(()=>show=v??false),title:const Text('Mostrar contraseñas'),contentPadding:EdgeInsets.zero),if(error.isNotEmpty)Text(error,style:const TextStyle(color:Colors.redAccent)),const SizedBox(height:18),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('GUARDAR CONTRASEÑA'))])));}

class HomePage extends StatefulWidget { final String token; final Map<String,dynamic> profile; const HomePage({super.key,required this.token,required this.profile}); @override State<HomePage> createState()=>_HomePageState(); }
class _HomePageState extends State<HomePage>{int index=0; List jobs=[]; Map stats={}; bool busy=true;String period='Hoy';List<String> patios=List.of(patioLocations),buses=List.of(busCodes);
  bool get privileged=>widget.profile['role']!='Técnico';
  bool get globalAdmin=>['Administrador','Jefe'].contains(widget.profile['role']);
  bool get superAdmin=>widget.profile['username']?.toString().toLowerCase()=='santos.jahuira';
  String get today=>DateTime.now().toIso8601String().substring(0,10);
  List get todayJobs=>jobs.where((j)=>j['FECHA_ISO']==today).toList();
  List get displayedJobs=>period=='Hoy'?todayJobs:jobs;
  @override void initState(){super.initState();load();}
  Future<void> load() async {try{final c=await api({'action':'getCatalogs','token':widget.token});if(c['ok']==true){patios=List<String>.from(c['data']['patios']);buses=List<String>.from(c['data']['buses']);}final j=await api({'action':'listJobs','token':widget.token}); if(j['ok']==true)jobs=j['data']??[]; if(privileged){final d=await api({'action':'dashboard','token':widget.token}); if(d['ok']==true)stats=d['data']??{};}}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context){final pages=[overview(),jobsPage(),const SizedBox(),if(privileged)dashboard(),profile()];return Scaffold(appBar:AppBar(backgroundColor:const Color(0xffa66d00),title:Text('UMA · ${widget.profile['area']}'),actions:[Padding(padding:const EdgeInsets.all(10),child:CircleAvatar(child:Text((widget.profile['name']??'U').toString()[0]))) ]),body:busy?const Center(child:CircularProgressIndicator()):pages[index],floatingActionButton:index==2?null:FloatingActionButton(backgroundColor:const Color(0xffe3aa39),foregroundColor:Colors.black,onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>JobForm(token:widget.token,patios:patios,buses:buses))).then((_)=>load()),child:const Icon(Icons.add)),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i){if(i==2){Navigator.push(context,MaterialPageRoute(builder:(_)=>JobForm(token:widget.token,patios:patios,buses:buses))).then((_)=>load());}else setState(()=>index=i);},destinations:[const NavigationDestination(icon:Icon(Icons.home_outlined),label:'Inicio'),const NavigationDestination(icon:Icon(Icons.history),label:'Trabajos'),const NavigationDestination(icon:Icon(Icons.add_circle_outline),label:'Registrar'),if(privileged)const NavigationDestination(icon:Icon(Icons.bar_chart),label:'Panel'),const NavigationDestination(icon:Icon(Icons.person_outline),label:'Perfil')]));}
  Widget overview()=>ListView(padding:const EdgeInsets.all(18),children:[Text('Buen día, ${widget.profile['name']}',style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)),Text('${widget.profile['role']} · ${widget.profile['location']??''}',style:const TextStyle(color:Colors.white60)),if(globalAdmin)const Padding(padding:EdgeInsets.only(top:6),child:Text('Vista general de todo el personal',style:TextStyle(color:Color(0xffe7b653)))),const SizedBox(height:22),const Text('Resumen de hoy',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:10),Row(children:[metric('En progreso',todayJobs.where((x)=>x['ESTADO']=='En progreso').length.toString()),const SizedBox(width:10),metric('Finalizados',todayJobs.where((x)=>x['ESTADO']=='Finalizado').length.toString())]),const SizedBox(height:24),Text(privileged?'Trabajos pendientes del personal':'Trabajos por continuar',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),...jobs.where((x)=>x['ESTADO']!='Finalizado').map(jobCard)]);
  Widget metric(String l,String v)=>Expanded(child:Card(color:const Color(0xff242119),child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[Text(v,style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Color(0xffe7b653))),Text(l)]))));
  Widget jobsPage()=>ListView(padding:const EdgeInsets.all(18),children:[Text(globalAdmin?'Trabajos de todo el personal':privileged?'Trabajos del personal del área':'Mis trabajos',style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),const SizedBox(height:12),SegmentedButton<String>(segments:const [ButtonSegment(value:'Hoy',label:Text('Hoy'),icon:Icon(Icons.today)),ButtonSegment(value:'Mes',label:Text('Este mes'),icon:Icon(Icons.calendar_month))],selected:{period},onSelectionChanged:(v)=>setState(()=>period=v.first)),const SizedBox(height:14),if(displayedJobs.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No hay trabajos registrados en este período',style:TextStyle(color:Colors.white60)))),...displayedJobs.map(jobCard)]);
  Widget jobCard(dynamic j){
   final done=j['ESTADO']=='Finalizado'||num.tryParse('${j['AVANCE_ACTUAL']??0}')==100;
   final own=j['USUARIO']?.toString()==widget.profile['username']?.toString();
   final patio=j['PATIO']?.toString()??'';
   return Card(color:const Color(0xff242119),margin:const EdgeInsets.symmetric(vertical:7),child:ListTile(
    onTap:done||!own?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>JobForm(token:widget.token,existing:Map<String,dynamic>.from(j),patios:patios,buses:buses))).then((_)=>load()),
    title:Text(j['DESCRIPCIÓN']?.toString()??'Trabajo'),
    subtitle:Text('${privileged?'${j['NOMBRE_COMPLETO']??j['USUARIO']??''} · ${j['ÁREA']??''}\n':''}${j['LUGAR']??''} · ${j['UBICACIÓN']??''}${patio.isEmpty?'':' · $patio'}\nAvance: ${j['AVANCE_ACTUAL']??0}% · ${j['TIEMPO_TOTAL']??''}'),
    isThreeLine:true,
    trailing:Icon(done?Icons.lock:own?Icons.play_circle_fill:Icons.visibility,color:done?Colors.greenAccent:const Color(0xffe7b653)),
   ));
  }
  Widget dashboard()=>ListView(padding:const EdgeInsets.all(18),children:[const Text('Dashboard general UMA',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:16),Row(children:[metric('Trabajos','${stats['total']??0}'),const SizedBox(width:10),metric('Finalizados','${stats['completed']??0}')]),const SizedBox(height:10),Row(children:[metric('En progreso','${stats['inProgress']??0}'),const SizedBox(width:10),metric('Horas','${((stats['totalMinutes']??0)/60).toStringAsFixed(1)}')]),if(superAdmin)...[const SizedBox(height:24),const Text('Gestión de Superadministrador',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Color(0xffe7b653))),const SizedBox(height:10),FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AdminUsersPage(token:widget.token,patios:patios))),icon:const Icon(Icons.manage_accounts),label:const Text('Gestionar usuarios y personal')),const SizedBox(height:10),OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CatalogAdminPage(token:widget.token))).then((_)=>load()),icon:const Icon(Icons.directions_bus),label:const Text('Gestionar patios y buses'))]]);
  Widget profile()=>ListView(padding:const EdgeInsets.all(24),children:[const CircleAvatar(radius:42,child:Icon(Icons.person,size:42)),const SizedBox(height:14),Text(widget.profile['name']??'',textAlign:TextAlign.center,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),Text(widget.profile['role']??'',textAlign:TextAlign.center,style:const TextStyle(color:Color(0xffe7b653))),const Divider(height:36),ListTile(title:const Text('Usuario'),trailing:Text(widget.profile['username']??'')),ListTile(title:const Text('Área'),trailing:Text(widget.profile['area']??'')),FilledButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ChangePasswordPage(token:widget.token,profile:widget.profile))),icon:const Icon(Icons.password),label:const Text('Cambiar contraseña')),const SizedBox(height:10),OutlinedButton(onPressed:()async{await SessionStore.clear();if(!context.mounted)return;Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const LoginPage()),(_)=>false);},child:const Text('Cerrar sesión'))]);
}

class JobForm extends StatefulWidget{final String token;final Map<String,dynamic>? existing;final List<String> patios,buses;const JobForm({super.key,required this.token,this.existing,required this.patios,required this.buses});@override State<JobForm>createState()=>_JobFormState();}
class _JobFormState extends State<JobForm>{
 final desc=TextEditingController(),asset=TextEditingController(),patio=TextEditingController(),order=TextEditingController(),notes=TextEditingController();
 final requestId='JOB-${DateTime.now().microsecondsSinceEpoch}';
 String place='Patio',progress='50',start='08:00',end='16:00';
 bool usedParts=false,busy=false;int previousProgress=0;

 bool get continuing=>widget.existing!=null;
 String get existingId{
  if(!continuing)return '';
  for(final entry in widget.existing!.entries){if(entry.value.toString().startsWith('TR-'))return entry.value.toString();}
  return widget.existing!['ID_TRABAJO']?.toString()??'';
 }
 List<String> get progressOptions=>['25','50','75','100'].where((x)=>int.parse(x)>previousProgress).toList();

 @override void initState(){
  super.initState();
  if(continuing){
   final job=widget.existing!;
   place=job['LUGAR']?.toString()??'Patio';
   asset.text=job['UBICACIÓN']?.toString()??'';
   patio.text=job['PATIO']?.toString()??(place=='Patio'?asset.text:'');
   order.text=job['NRO_OT']?.toString()??'';
   previousProgress=int.tryParse('${job['AVANCE_ACTUAL']??0}')??0;
   progress=progressOptions.isNotEmpty?progressOptions.first:'100';
  }
 }

 void message(String value)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value)));

 Future<void> pickTime(bool forStart)async{
  final current=(forStart?start:end).split(':');
  final selected=await showTimePicker(context:context,initialTime:TimeOfDay(hour:int.parse(current[0]),minute:int.parse(current[1])),helpText:forStart?'SELECCIONAR HORA DE INICIO':'SELECCIONAR HORA DE FIN',cancelText:'CANCELAR',confirmText:'ACEPTAR',builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(alwaysUse24HourFormat:true),child:child!));
  if(selected==null)return;
  final value='${selected.hour.toString().padLeft(2,'0')}:${selected.minute.toString().padLeft(2,'0')}';
  setState((){if(forStart)start=value;else end=value;});
 }

 Widget timeField(String label,String value,bool forStart)=>InkWell(onTap:()=>pickTime(forStart),borderRadius:BorderRadius.circular(12),child:InputDecorator(decoration:InputDecoration(labelText:label,suffixIcon:const Icon(Icons.access_time)),child:Text(value,style:const TextStyle(fontSize:18))));

 Future<void> save()async{
  if(patio.text.trim().isEmpty){message('Selecciona el patio');return;}
  if(place=='Bus'&&asset.text.trim().isEmpty){message('Selecciona el código del bus');return;}
  if(place=='Bus'&&!widget.buses.contains(asset.text.trim().toUpperCase())){message('Selecciona un código de bus válido');return;}
  if(!widget.patios.contains(patio.text.trim().toUpperCase())){message('Selecciona una ubicación de patio válida');return;}
  if(place=='Bus'&&order.text.trim().isEmpty){message('Ingresa el número de OT');return;}
  if(desc.text.trim().isEmpty){message('Describe el trabajo realizado');return;}
  final timePattern=RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  if(!timePattern.hasMatch(start)||!timePattern.hasMatch(end)){message('Usa horas válidas en formato HH:mm');return;}
  if(start==end){message('La hora de inicio y fin no pueden ser iguales');return;}
  setState(()=>busy=true);
  try{
   final isBus=place=='Bus';
   final r=await api({'action':'saveJob','token':widget.token,'job':{'requestId':requestId,'id':continuing?existingId:null,'date':DateTime.now().toIso8601String(),'place':place,'patio':patio.text.trim(),'asset':isBus?asset.text.trim():patio.text.trim(),'hasOrder':isBus,'order':isBus?order.text.trim():'','description':desc.text.trim(),'start':start,'end':end,'progress':int.parse(progress),'materials':usedParts?'Sí':'No','notes':notes.text.trim()}});
   if(!mounted)return;
   if(r['ok']==true){message('Guardado · ${r['data']['durationText']}');Navigator.pop(context);}else{message(r['error']?.toString()??'No se pudo guardar');setState(()=>busy=false);}
  }catch(e){if(mounted){message('No se pudo conectar con el servidor');setState(()=>busy=false);}}
 }

 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(continuing?'Continuar trabajo':'Registrar trabajo')),body:ListView(padding:const EdgeInsets.all(18),children:[
  if(continuing)Card(color:const Color(0xff29251b),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Trabajo original',style:TextStyle(color:Color(0xffe7b653),fontWeight:FontWeight.bold)),const SizedBox(height:6),Text(widget.existing!['DESCRIPCIÓN']?.toString()??''),Text('Avance anterior: $previousProgress% · ${widget.existing!['TIEMPO_TOTAL']??''}',style:const TextStyle(color:Colors.white60))]))),
  DropdownButtonFormField<String>(value:place,decoration:const InputDecoration(labelText:'Tipo de trabajo'),items:['Patio','Bus'].map((x)=>DropdownMenuItem<String>(value:x,child:Text(x))).toList(),onChanged:continuing?null:(v)=>setState((){place=v!;asset.clear();patio.clear();order.clear();})),
  const SizedBox(height:12),
  DropdownButtonFormField<String>(
   value:widget.patios.contains(patio.text)?patio.text:null,
   isExpanded:true,
   decoration:const InputDecoration(labelText:'Ubicación del patio'),
   items:widget.patios.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
   onChanged:(v)=>setState(()=>patio.text=v??''),
  ),
  if(place=='Bus')...[
  const SizedBox(height:12),
  Autocomplete<String>(
   initialValue:TextEditingValue(text:asset.text),
   optionsBuilder:(value){
    final query=value.text.trim().toUpperCase().replaceAll('-','');
    if(query.isEmpty)return const Iterable<String>.empty();
    return widget.buses.where((code){final compact=code.replaceAll('-','');final number=code.split('-').last;return compact.contains(query)||number.startsWith(query);}).take(12);
   },
   onSelected:(value)=>asset.text=value,
   fieldViewBuilder:(context,controller,focus,onSubmit)=>TextField(
    controller:controller,
    focusNode:focus,
    enabled:!continuing,textCapitalization:TextCapitalization.characters,
    onChanged:(value)=>asset.text=value.toUpperCase(),
    decoration:const InputDecoration(labelText:'Código del bus',hintText:'Escribe el número, por ejemplo 002'),
   ),
  ),
   const SizedBox(height:12),
   TextField(controller:order,enabled:!continuing,decoration:const InputDecoration(labelText:'Número de OT')),
  ],
  const SizedBox(height:12),
  TextField(controller:desc,maxLines:4,decoration:InputDecoration(labelText:continuing?'Trabajo realizado en esta continuación':'Trabajo realizado')),
  const SizedBox(height:12),
  Row(children:[Expanded(child:timeField('Inicio',start,true)),const SizedBox(width:10),Expanded(child:timeField('Fin',end,false))]),
  const SizedBox(height:12),
  DropdownButtonFormField(value:progress,decoration:const InputDecoration(labelText:'Nuevo avance'),items:progressOptions.map((x)=>DropdownMenuItem(value:x,child:Text('$x%'))).toList(),onChanged:(v)=>progress=v!),
  const SizedBox(height:12),
  SwitchListTile(contentPadding:const EdgeInsets.symmetric(horizontal:12),title:const Text('Usó repuestos solicitados de almacén'),subtitle:Text(usedParts?'Sí':'No'),value:usedParts,onChanged:(v)=>setState(()=>usedParts=v)),
  const SizedBox(height:12),
  TextField(controller:notes,decoration:const InputDecoration(labelText:'Observaciones')),
  const SizedBox(height:20),
  FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():Text(continuing?'Guardar continuación':'Guardar registro')),
 ]));}

class AdminUsersPage extends StatefulWidget{final String token;final List<String> patios;const AdminUsersPage({super.key,required this.token,required this.patios});@override State<AdminUsersPage>createState()=>_AdminUsersPageState();}
class _AdminUsersPageState extends State<AdminUsersPage>{List users=[];bool busy=true;
 @override void initState(){super.initState();load();}
 Future<void> load()async{final r=await api({'action':'listUsers','token':widget.token});if(mounted)setState((){users=r['ok']==true?r['data']??[]:[];busy=false;});}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Gestión de usuarios')),body:busy?const Center(child:CircularProgressIndicator()):ListView.builder(padding:const EdgeInsets.all(12),itemCount:users.length,itemBuilder:(c,i){final u=Map<String,dynamic>.from(users[i]);void edit()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>EditUserPage(token:widget.token,user:u,patios:widget.patios))).then((_)=>load());return Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(child:Icon(u['superadmin']==true?Icons.admin_panel_settings:Icons.person)),const SizedBox(width:12),Expanded(child:InkWell(onTap:edit,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(u['name']??u['username']??'',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text('ID: ${u['id']??''} · Usuario: ${u['username']}'),Text('Rol: ${u['role']} · Área: ${u['area']??''}'),Text('Patio: ${u['location']??'Sin asignar'}'),Text('Turno: ${u['shift']??'Sin asignar'}'),const SizedBox(height:4),const Text('Toca para editar',style:TextStyle(color:Color(0xffe7b653),fontSize:12))]))),Column(children:[Switch(value:u['active']==true,onChanged:u['superadmin']==true?null:(v)async{final r=await api({'action':'updateUser','token':widget.token,'username':u['username'],'active':v});if(r['ok']==true)load();}),IconButton(onPressed:edit,icon:const Icon(Icons.edit))])])));}),floatingActionButton:FloatingActionButton.extended(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>UserForm(token:widget.token,patios:widget.patios))).then((_)=>load()),icon:const Icon(Icons.person_add),label:const Text('Nuevo personal')));}

class EditUserPage extends StatefulWidget{final String token;final Map<String,dynamic> user;final List<String> patios;const EditUserPage({super.key,required this.token,required this.user,required this.patios});@override State<EditUserPage>createState()=>_EditUserPageState();}
class _EditUserPageState extends State<EditUserPage>{late final TextEditingController name,shift;late String area,role,location;late bool active;bool busy=false;
 bool get protected=>widget.user['superadmin']==true;
 @override void initState(){super.initState();name=TextEditingController(text:widget.user['name']?.toString()??'');shift=TextEditingController(text:widget.user['shift']?.toString()??'');area=widget.user['area']?.toString()??'TIC';role=widget.user['role']?.toString()??'Técnico';location=widget.patios.contains(widget.user['location'])?widget.user['location']:widget.patios.first;active=widget.user['active']==true;}
 Future<void> save()async{if(name.text.trim().isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('El nombre es obligatorio')));return;}setState(()=>busy=true);final r=await api({'action':'updateUser','token':widget.token,'username':widget.user['username'],'fullName':name.text.trim(),'area':area,'location':location,'shift':shift.text.trim(),'role':protected?'Administrador':role,'active':protected?true:active});if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r['ok']==true?'Datos actualizados correctamente':r['error'])));if(r['ok']==true)Navigator.pop(context);else setState(()=>busy=false);}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Editar usuario')),body:ListView(padding:const EdgeInsets.all(18),children:[Card(color:const Color(0xff29251b),child:ListTile(title:Text(widget.user['username']),subtitle:Text('${widget.user['id']}${protected?' · SUPERADMINISTRADOR':''}'),leading:Icon(protected?Icons.admin_panel_settings:Icons.badge,color:const Color(0xffe7b653)))),const SizedBox(height:12),TextField(controller:name,decoration:const InputDecoration(labelText:'Nombre completo')),const SizedBox(height:12),DropdownButtonFormField<String>(value:area,decoration:const InputDecoration(labelText:'Área'),items:['TIC','Mecánica','Electromecánica','Restauración','Maestranza'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>area=v!)),const SizedBox(height:12),DropdownButtonFormField<String>(value:location,decoration:const InputDecoration(labelText:'Patio base'),items:widget.patios.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>location=v!)),const SizedBox(height:12),TextField(controller:shift,decoration:const InputDecoration(labelText:'Turno')),const SizedBox(height:12),DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Rol'),items:['Técnico','Supervisor','Responsable','Jefe','Administrador'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:protected?null:(v)=>setState(()=>role=v!)),SwitchListTile(title:const Text('Usuario activo'),subtitle:Text(protected?'Protegido: siempre activo':active?'Puede ingresar':'Acceso bloqueado'),value:active,onChanged:protected?null:(v)=>setState(()=>active=v)),if(!protected)OutlinedButton.icon(onPressed:()async{final r=await api({'action':'resetPassword','token':widget.token,'username':widget.user['username']});if(!context.mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r['ok']==true?'Contraseña restablecida a 123456':r['error'])));},icon:const Icon(Icons.restart_alt),label:const Text('Restablecer contraseña a 123456')),const SizedBox(height:20),FilledButton.icon(onPressed:busy?null:save,icon:const Icon(Icons.save),label:Text(busy?'Guardando...':'Guardar cambios'))]));}

class CatalogAdminPage extends StatefulWidget{final String token;const CatalogAdminPage({super.key,required this.token});@override State<CatalogAdminPage>createState()=>_CatalogAdminPageState();}
class _CatalogAdminPageState extends State<CatalogAdminPage>{List patios=[],buses=[];bool busy=true;
 @override void initState(){super.initState();load();}
 Future<void> load()async{final r=await api({'action':'getCatalogs','token':widget.token});if(mounted)setState((){if(r['ok']==true){patios=r['data']['patios'];buses=r['data']['buses'];}busy=false;});}
 Future<void> add(String type)async{final controller=TextEditingController();final value=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:Text(type=='bus'?'Agregar bus':'Agregar patio'),content:TextField(controller:controller,textCapitalization:TextCapitalization.characters,decoration:InputDecoration(hintText:type=='bus'?'Ejemplo: BA-200':'Nombre del patio')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(c,controller.text),child:const Text('Guardar'))]));if(value==null||value.trim().isEmpty)return;final r=await api({'action':'addCatalog','token':widget.token,'type':type,'value':value});if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r['ok']==true?'Agregado correctamente':r['error'])));if(r['ok']==true)load();}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Patios y buses')),body:busy?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(18),children:[Card(child:ListTile(leading:const Icon(Icons.location_on),title:Text('${patios.length} patios'),subtitle:const Text('Ubicaciones disponibles'),trailing:IconButton(onPressed:()=>add('patio'),icon:const Icon(Icons.add)))),Card(child:ListTile(leading:const Icon(Icons.directions_bus),title:Text('${buses.length} buses'),subtitle:const Text('Códigos disponibles'),trailing:IconButton(onPressed:()=>add('bus'),icon:const Icon(Icons.add)))),const SizedBox(height:16),const Text('Los nuevos patios y buses aparecerán automáticamente en todos los celulares.',style:TextStyle(color:Colors.white60))]));}

class UserForm extends StatefulWidget{final String token;final List<String> patios;const UserForm({super.key,required this.token,required this.patios});@override State<UserForm>createState()=>_UserFormState();}
class _UserFormState extends State<UserForm>{final name=TextEditingController(),user=TextEditingController(),location=TextEditingController(),shift=TextEditingController();String area='TIC';bool busy=false;
 Future<void> save()async{final messenger=ScaffoldMessenger.of(context);if(name.text.trim().isEmpty){messenger.showSnackBar(const SnackBar(content:Text('Ingresa el nombre completo')));return;}if(!RegExp(r'^[a-zA-Z0-9._-]{3,30}$').hasMatch(user.text.trim())){messenger.showSnackBar(const SnackBar(content:Text('El usuario debe tener entre 3 y 30 caracteres, sin espacios')));return;}if(location.text.isEmpty){messenger.showSnackBar(const SnackBar(content:Text('Selecciona el patio base')));return;}if(shift.text.trim().isEmpty){messenger.showSnackBar(const SnackBar(content:Text('Ingresa el turno')));return;}setState(()=>busy=true);try{final r=await api({'action':'createOperationalUser','token':widget.token,'username':user.text.trim().toLowerCase(),'fullName':name.text.trim(),'area':area,'location':location.text,'shift':shift.text.trim()});if(!mounted)return;messenger.showSnackBar(SnackBar(content:Text(r['ok']==true?'Usuario creado con contraseña 123456':r['error'])));if(r['ok']==true)Navigator.pop(context);else setState(()=>busy=false);}catch(e){if(mounted){messenger.showSnackBar(const SnackBar(content:Text('No se pudo conectar con el servidor')));setState(()=>busy=false);}}}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Nuevo personal operativo')),body:ListView(padding:const EdgeInsets.all(18),children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Nombre completo *')),const SizedBox(height:12),TextField(controller:user,decoration:const InputDecoration(labelText:'Usuario *')),const SizedBox(height:12),DropdownButtonFormField<String>(value:area,decoration:const InputDecoration(labelText:'Área *'),items:['TIC','Mecánica','Electromecánica','Restauración','Maestranza'].map((x)=>DropdownMenuItem<String>(value:x,child:Text(x))).toList(),onChanged:(v)=>area=v!),const SizedBox(height:12),DropdownButtonFormField<String>(decoration:const InputDecoration(labelText:'Patio base *'),items:widget.patios.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>location.text=v??''),const SizedBox(height:12),TextField(controller:shift,decoration:const InputDecoration(labelText:'Turno *')),const SizedBox(height:8),const Text('* Campos obligatorios',style:TextStyle(color:Colors.white60)),const SizedBox(height:20),FilledButton(onPressed:busy?null:save,child:busy?const CircularProgressIndicator():const Text('Crear usuario técnico'))]));}
