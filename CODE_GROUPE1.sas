/*__________________________________________________________________________________________________________________________________*/
/* 										PROJET ÉTUDE DE CAS SAS - GROUPE 1
/*														M2 TIDE
/*_________________________________________________________________________________________________________________________________*/
/*__________________________________________________________________________________________________________________________________*/
/*														CREATION DES MACROS
/*														   & DES FORMATS
/*_________________________________________________________________________________________________________________________________*/
/*LE CHEMIN*/
%let chemin =/folders/myfolders/SAS_M2_TIDE/EDC/PROJET;
libname projet "&chemin";

/* 1. CREATION FORMAT fmois : POUR EXTRAIRE LE MOISs*/
PROC FORMAT library=work;
	VALUE Fmois 1="Janvier" 2="Fevrier" 3="Mars" 4="Avril" 5="Mai" 6="Juin" 
		7="Juillet" 8="Aout" 9="Septembre" 10="Octobre" 11="Novembre" 12="Decembre";
RUN;


/* 2. MACRO DE SELECTION DES VARIABLES AVEC PLUS X% DE VALEUR NON MANQUANTE */
%MACRO MISSING_PERCENT(table_in=, percent=, table_out=);
	proc means data=&table_in. noprint;
		output out=missing_data (drop=_type_);
	run;

	data missing_data;
		set missing_data;
		where _Stat_='N';

		if _N_=1 then
			call symput("n_total", _FREQ_);
	run;

	%put &n_total.;

	proc transpose data=missing_data out=missing_data;
	run;

	data missing_data;
		set missing_data;
		where _name_ NE '_FREQ_' and Col1 > (&n_total. * &percent.)/100;
		rename _name_=keep_var;
	run;

	proc sql noprint;
		SELECT keep_var INTO :keep_var separated BY ' ' FROM missing_data;
	quit;

	%put keep_var=&keep_var;

	data &table_out.;
		set &table_in.;
		keep _character_ &keep_var.;
	run;
%mend;

/* 3. MACRO DE REMPLACEMENT DES VALEURS NEGATIVES PAR LA VALEUR PRECEDENTE*/
%macro REPLACE_NEG(table_in=, table_out=);
	proc means data=&table_in. NOPRINT;
		output out=negative_data (drop=_freq_ _type_);
	run;

	data negative_data;
		set negative_data;
		where _Stat_='MIN';
	run;

	proc transpose data=negative_data out=negative_data;
	run;

	data negative_data;
		set negative_data;
		where Col1 < 0;
		rename _name_=neg_var;
	run;

	proc sql noprint;
		SELECT neg_var INTO :neg_var separated BY ' ' FROM negative_data;
		SELECT count(*) INTO :nb FROM negative_data;
	quit;

	%put neg_var=&neg_var;
	%put nb=&nb;

	DATA &table_out. (DROP=correct);
		SET &table_in.;

		%do i=1 %to &nb.;
			%let x=%scan(&neg_var, &i., ' ');
			RETAIN correct;

			IF &x. >=0 THEN
				correct=&x;
			ELSE
				&x.=correct;
		%end;
	RUN;

%mend;

/* 4. MACRO REALISANT DES GRAPHS DE MEAN PAR CONTINENT EN FONCTION DU TEMPS POUR UNE VARIABLE SELECTIONNEE*/
%macro GRAPH_TIME(table_in=, var_use=);
	data continent_data;
		set &table_in.;
		keep continent;

	proc sort data=continent_data out=continent_data nodupkey;
		by continent;
	run;

	proc sql noprint;
		SELECT continent INTO :continent separated BY ' ' FROM continent_data;
		SELECT count(*) INTO :nb FROM continent_data;
	quit;

	%put continent=&continent;
	%put nb=&nb;

	%do i=1 %to &nb.-1;
		%let x=%scan(&continent, &i., ' ');

		proc means data=&table_in. (where=(continent="&x.")) noprint;
			class date;
			var &var_use.;
			output out=&x.(drop=_type_ _freq_) mean=&x.;
		run;

		%put &x.;
	%end;

	proc means data=&table_in. (where=(continent ne "World")) noprint;
		class date;
		var &var_use.;
		output out=World(drop=_type_ _freq_) mean=World;
	run;

	data All_continent;
		merge &continent;
		by date;
	run;

	title1 "Évolution moyenne de &var_use. sur la période considérée ";

	proc sgplot data=all_continent;
		series y=world x=date;

		%do i=1 %to &nb.-1;
			%let x=%scan(&continent, &i., ' ');
			series y=&x. x=date;
		%end;
	run;

%mend;

/* 5. MACRO POUR L'ANALYSE DESCRIPTIVE : AFFICHE UNE TABLE QUI DONNE POUR CHAQUE MOIS LE CONTINENT QUI ATTEINT LE MAXIMUM POUR UNE VARIABLE DONNEE */
%macro MAX_BY_MONTH(table_in=, table_out=, nb=, var_use=);
	data continent_for_analyse;
		set &table_in.;
		where continent ne "World" and mois ne 11 and mois ne 12;
	run;

	%do i=1 %to &nb.;
		%let x=%scan(&var_use., &i., ' ');

		PROC MEANS DATA=continent_for_analyse (drop=date) MAX noprint;
			class mois;
			var &x.;
			OUTPUT OUT=MAX_&x. (drop=_TYPE_ _FREQ_) max=&x.
			maxid(&x.(continent))=Continent&i.
			maxid(&x.(location))=Pays&i.;
		RUN;

	%end;

	data &table_out.;
		set MAX_%scan(&var_use., 1, ' ');
	run;

	%do i=2 %to &nb.;
		%let x=%scan(&var_use., &i., ' ');

		data &table_out.;
			merge &table_out. MAX_&x.;
			by mois;
		run;

	%end;
%mend;

/* 6. MACRO POUR FAIRE DES BAR PLOT PAR MOIS POUR L'ANALYSE DESCRIPTIVE PAR MOIS A L'ECHELLE MONDIAL ET VISION PAR CONTINENT*/
%macro BAR_MONTH_CONTINENT(nb=, var_list=);
	%let var_bar=&var_list.;

	%do i=1 %to &nb.;
		%let x=%scan(&var_bar., &i., ' ');

		PROC SGPLOT DATA=projet.covid (where=(mois < 11 and continent ne "World"));
			styleattrs datacolors=(purple GRGY STGY PAV STPK LIOY) 
				backcolor=White  /*wallcolor=BIGB*/;
			VBAR mois/response=&x. stat=mean group=continent barwidth=.5 seglabel 
				transparency=0.3 DATASKIN=PRESSED;
			keylegend / location=inside position=topleft across=1;
			yaxis labelattrs=(color=BIGB weight=bold) valueattrs=(color=BIGB);
			xaxis label="Mois" labelattrs=(color=BIGB weight=bold) 
				valueattrs=(color=BIGB) FITPOLICY=None;
		RUN;

	%end;
%mend;

/* 7. MACRO POUR FAIRE DES GROUPES PAR PAYS A UNE DATE DONNEE (L'OBJECTIF AVOIR DES TABLEAUX PLUS INTERESSANTS ET COURT, ET POUVOIR EXPLOITER LES COLONNES D'INDICATEURS CONSTANTS)*/
%macro GROUPE_PAYS();
	data pays;
		set projet.covid;
		where date=mdy(11, 01, 2020) and continent ne "World";
	run;

	PROC UNIVARIATE DATA=pays noprint;
		/* Grâce à la PROC UNIVARIATE nous formons 3 groupes selon la distribution des quantiles pour chaque variable*/
		VAR total_deaths_per_million human_development_index 
			hospital_beds_per_thousand diabetes_prevalence;
		OUTPUT OUT=TEMP PCTLPTS=33 66 PCTLPRE=deaths_ IDH_ bed_ diab_ PCTLNAME=q33 
			q66;
	RUN;

	data _null_;
		set TEMP;
		call symput("deaths_q33", deaths_q33);
		call symput("deaths_q66", deaths_q66);
		call symput("IDH_q33", IDH_q33);
		call symput("IDH_q66", IDH_q66);
		call symput("Bed_q33", Bed_q33);
		call symput("Bed_q66", Bed_q66);
		call symput("diab_q33", diab_q33);
		call symput("diab_q66", diab_q66);
	run;

	PROC FORMAT library=work;
		VALUE Format_deaths 
			0- &deaths_q33.="Premier tier des pays ayant le moins de morts /million"
			&deaths_q33.<- &deaths_q66.="Deuxieme tier ayant le moins de morts /million"
			&deaths_q66.<- high="Dernier tier ayant le plus de morts /million";
		VALUE Format_IDH 0- &IDH_q33.="Premier tier des pays ayant le plus petit IDH"
			&IDH_q33.<- &IDH_q66.="Deuxieme tier ayant le plus petit IDH"
			&IDH_q66.<- 1="Dernier tier ayant le plus gros IDH";
		VALUE Format_BED 
			0- &BED_q33.="Premier tier des pays ayant le moins de lits /millier"
			&BED_q33.<- &BED_q66.="Deuxieme tier ayant le moins de lits /millier"
			&BED_q66.<- high="Dernier tier ayant le plus de lits /millier";
		VALUE Format_DIAB 
			0- &DIAB_q33.="Premier tier des pays ayant le moins de diabètes"
			&DIAB_q33.<- &DIAB_q66.="Deuxieme tier ayant le moins de diabètes"
			&DIAB_q66.<- 100="Dernier tier ayant le plus de diabètes";
	RUN;

	PROC UNIVARIATE DATA=pays noprint;
		VAR aged_70_older;
		OUTPUT OUT=TEMP PCTLPTS=50 PCTLPRE=aged70_ PCTLNAME=q50;
	RUN;

	data _null_;
		set TEMP;
		call symput("aged70_q50", aged70_q50);
	run;

	proc format library=work;
		value format_age 
			0 - &aged70_q50.="Pays où la part des plus de 70 ans est la plus faible"
			&aged70_q50. - 100="Pays où la part des plus de 70 ans est la plus grande";
	run;

%mend;

/* 8. MACRO POUR APPLIQUER LES FORMATS */
%MACRO APPLY_FORMAT(table_in=, table_out=);
	data &table_out.;
		set &table_in.;
		groupe_IHD=human_development_index;
		groupe_deaths=total_deaths_per_million;
		groupe_bed=hospital_beds_per_thousand;
		groupe_diab=diabetes_prevalence;
		group_70=aged_70_older;
		format groupe_IHD Format_IDH. groupe_deaths Format_deaths. groupe_bed 
			Format_bed. groupe_diab Format_diab. group_70 format_age.;
	run;

%mend;

/*9. MACRO POUR TRANSFORMER LES PROC FREQ POUR LES AFFICHER DANS LE DIAPO*/
%macro transfo_crossfreq(var=, var2=);
	ods exclude all;
	ods output CrossTabFreqs=freq_tab (drop=table _table_ frequency _type_ 
		missing);

	proc freq data=pays;
		tables (&var.) * &var2. / nofreq nopercent norow;
	run;

	PROC SORT DATA=freq_tab OUT=freq_tab;
		BY &var.;
	RUN;

	data freq_tab;
		set freq_tab;
		where colpercent ne .;
	run;

	PROC TRANSPOSE DATA=freq_tab OUT=freq_tab;
		id &var2.;
		by &var.;
	run;

	data freq_tab;
		set freq_tab;
		drop _name_ _label_;
	run;

	ods output clear;
	ods exclude none;
%mend;

/*_________________________________________________________________________________________________________________________________*/
/*__________________________________________________________________________________________________________________________________*/
/*														PREPARATION DES DONNEES
/*_________________________________________________________________________________________________________________________________*/
/* Préparation de l'importation de la BDD */
proc import datafile="&chemin./owid-covid-codebook.xlsx" out=projet.name 
		dbms=xlsx replace;
	getnames=yes;
run;

data var_num1;
	/* récupération des noms des variables numériques (avant test_units)*/
	set projet.name (firstobs=5 obs=32);
	keep column;
	column=compress(substr(column, 1, 32));
	rename column=num1;
run;

data var_num2;
	/* récupération des noms des variables numériques (après test_units)*/
	set projet.name (firstobs=34);
	keep column;
	column=compress(substr(column, 1, 32));
	rename column=num2;
run;

data var_char;
	/* récupération des variables caractères*/
	set projet.name (obs=3);
	keep column;
	column=compress(substr(column, 1, 32));
	rename column=char;
run;

proc sql noprint;
	/*pour créer la macro*/
	SELECT num1 INTO :num1 separated BY ' ' FROM var_num1;
	SELECT num2 INTO :num2 separated BY ' ' FROM var_num2;
	SELECT char INTO :char separated BY ' $ ' FROM var_char;
quit;

%let char=&char;
%let num1=&num1;
%let num2=&num2;

/* Importation de la BDD */
data projet.covid;
	infile "&chemin./owid-covid-data.csv" DLM="," missover dsd firstobs=2;
	length iso_code continent location $ 25. tests_units $ 25.;
	input &char. $  date &num1. tests_units $ &num2.;
	informat date YYMMDD10. &num1. best12. &num2. best12.;
	format date YYMMDD10. &num1. best12. &num2. best12.;
run;

/* Nettoyage de la BDD */
/*Comme il y a des variables avec beaucoup de valeur manquantes on conserve les variables qui ont plus de 40% de valeurs non manquantes.*/
%MISSING_PERCENT(table_in=projet.covid, percent=40, table_out=projet.covid);

/*Nous pouvons faire une PROC MEANS pour visualiser l'ensemble de nos données.*/
/*
PROC MEANS DATA= PROJET.COVID;
RUN;
*/
/* On remarque la présence de valeur négative pour les variables :
new_cases_smoothed, new_deaths, new_deaths_smoothed, total_cases_per_million, new_cases_per_million, new_cases_smoothed_per_million,
new_deaths_per_million, new_deaths_smoothed_per_million.
Ce qui n'a pas de sens. En recherchant sur internet la valeur de ces variables pour certains pays à certaines dates
nous avons déduit que nous pouvions remplacer les valeurs négatives par la valeur prise à le jour précedent.
*/

%REPLACE_NEG(table_in=projet.covid, table_out=projet.covid);

/*AJOUT DES MOIS & REMPLACEMENT POUR CONTINENT*/
data Projet.Covid;
	set projet.covid;
	mois=month(date);
	format mois Fmois.;
	where location ne "International";

	/*Comme on ne comprend pas cette modalité, donc on supprime*/
	if continent=' ' then
		continent="World";
	continent=compress(continent);

	if total_deaths_per_million=. then
		total_deaths_per_million=0;

	if total_cases_per_million ne 0 then
		deaths_per_cases=(total_deaths_per_million / total_cases_per_million)*100;

	/*Pourcentage de mortalité des personnes atteintes du covid*/
run;

%GROUPE_PAYS;

/*la macro fait des groupes de même proportion par pays pour des variables données*/
%APPLY_FORMAT(table_in=pays, table_out=pays);

/*On applique les formats des groupes*/
%APPLY_FORMAT(table_in=projet.covid, table_out=projet.covid);

/*FIN DE LA PREPARATION DE LA BDD*/
/*_____________________________________________________________________________________________________________________*/
/*                                                             ANALYSE DESCRIPTIVE                                                             */
/*_____________________________________________________________________________________________________________________*/
/* PAGE D'ACCUEIL */
ods escapechar='^';
ODS HTML PATH="&chemin." (url='/folders/myfolders/SAS_M2_TIDE/EDC/PROJET/') 
	BODY='index.html' STYLE=htmlblue headtext='<style type="text/css"> a {text-decoration:none}</style>';
title j=center " ^S={preimage='Logo.png'} ";
TITLE2 h=24pt "ÉTUDE - COVID-19";
TITLE3 '<A HREF="https://www.linkedin.com/in/alissa-djema-a71006156">Alissa DJEMA</A> -
		<A HREF="https://www.linkedin.com/in/alexandra-zhou-b483b61a2">Alexandra ZHOU</A> - 
		<A HREF="https://www.linkedin.com/in/elodie-perron-543b28116">Elodie PERRON</A> - 
		<A HREF="https://www.linkedin.com/in/samy-bentayeb-9a7419134">Samy BENTAYEB</A>';
ods layout gridded width=70% columns=3 rows=2;
ods region column=2;
ods layout gridded rows=3;
ods region row=1;
ods html text="^S={preimage='covid.jpg'}";
ods region width=50% height=70%;
ods html text="^S={just=c font_size=9pt font_face=Arial}Le double objectif de ce travail est de mettre en application
					les différentes procédures SAS que nous avons découvert lors du cours
					d'Étude de cas SAS. Pour ce faire, nous avons à disposition des données
					journalières à l’échelle mondiale de l’épidémie de Covid-19 sur la période
					du 31 décembre 2019 au 02 novembre 2020. Ainsi, le second objectif est de 
					pouvoir présenter des informations clefs sur le plan sanitaire à l’échelle
					mondiale puis par continent. ^n 
					Nos résultats sont donc présentés dans cette page HTML sous forme d’une petite revue. ";
ods region row=2;
ods layout end;

title4 height=14pt "Voici les différents éléments de nos analyses";

ods layout gridded width=70% columns =3;
ods region;
proc odstext;
	p '<A HREF="page_1.html">Situation mondiale</A>'/ style=[just=c asis=on font_weight=bold borderleftcolor=#E5B82E borderleftwidth=2pt
    borderrightcolor=#E5B82E borderrightwidth=2pt
    borderbottomcolor=#E5B82E borderbottomwidth=2pt 
    bordertopcolor=#E5B82E bordertopwidth=2pt fontsize=12pt backgroundcolor=#E5B82E foreground=white];
RUN;

ods region;
proc odstext;
	p '<A HREF="page_2.html">La COVID-19 dans le monde</A>'/ style=[just=c asis=on font_weight=bold borderleftcolor=#E5B82E borderleftwidth=2pt
    borderrightcolor=#E5B82E borderrightwidth=2pt
    borderbottomcolor=#E5B82E borderbottomwidth=2pt 
    bordertopcolor=#E5B82E bordertopwidth=2pt fontsize=12pt backgroundcolor=#E5B82E foreground=white];
RUN;

ods region;
proc odstext;
	p '<A HREF="continents.html">Quel impact sur chaque continent ?</A>'/ style=[just=c asis=on font_weight=bold borderleftcolor=#E5B82E borderleftwidth=2pt
    borderrightcolor=#E5B82E borderrightwidth=2pt
    borderbottomcolor=#E5B82E borderbottomwidth=2pt 
    bordertopcolor=#E5B82E bordertopwidth=2pt fontsize=12pt backgroundcolor=#E5B82E foreground=white];
RUN;
ods layout end;

/* 
	p '<A HREF="page_2.html">La COVID-19 dans le monde</A>'/ style=[just=c fontsize=12pt];
	p '<A HREF="continents.html">Quel impact sur chaque continent ?</A>'/ style=[just=c fontsize=12pt];*/


ods layout end;
ODS HTML CLOSE;
ods _all_ close;
title;

/************ PAGE INTRODUCTION **************/
ods escapechar='^';
ODS HTML PATH="&chemin." (url='/folders/myfolders/SAS_M2_TIDE/EDC/PROJET/') 
	BODY='page_1.html' STYLE=htmlblue;
title j=center " ^S={preimage='Logo.png'} ";
TITLE2 h=24pt "ÉTUDE DE CAS SAS - L'épidémie de COVID-19";


ods layout gridded width=60% columns=2;

ods region;
title1 "Situation à l'échelle mondial de l'épidémie de Covid-19 (01/11/2020)";
proc report data=projet.covid split='@'
		style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
		style(column)=[background=white fontsize=7pt];
	where location="World" and date=mdy(11, 01, 2020);
	column total_cases total_deaths population median_age handwashing_facilities;
	define total_cases / CENTER "Nombre total de cas";
	define total_deaths / CENTER "Nombre total de morts";
	define population / CENTER "Population totale";
	define median_age / CENTER "Âge médian";
	define handwashing_facilities / CENTER 
		"Part de la pop. ayant accès à @ des instalations de lavage de mains (en %)";
	footnote "D’après l’Organisation Mondiale de la Santé (l’OMS) , la COVID-19 est 
				une maladie infectieuse due à un coronavirus SARS-COV2 dont les premiers cas 
				d’infection ont été signalés sur le territoire chinois en décembre 2019.
				Transmissible par voie orale et nasale lorsqu’une personne parle, tousse, éternue etc. 
				il ne tarde pas à se répandre dans le monde entier depuis le premier semestre 2020. ^n
				Quelle est la situation actuelle de la pandémie ? ^n
				Au 1er novembre 2020, sur une population de 7 794 798 729 individus avec un âge médian 
				de 30 ans, le nombre de personnes ayant été infectées par le virus est de 46 169 115, 
				soit près de 5,92% de la population mondiale. Le nombre de décès s’élève à 1 196 367, soit 0,15% de la population. 
				La mortalité liée au covid-19 à l’échelle mondial
				est ainsi de 2,59%. Ces résultats sont cohérents avec les chiffres dont Statista annonce
				 pour la date du 2 novembre qui indique un total de 46,5 millions d’infections liées au 
				 virus dans le monde et 1,2 million de décès. ^n
				 Par ailleurs, seulement 60% de la population a accès à des installations de lavage 
				 de mains. Or un lavage de mains insuffisant expose des millions de personnes à un risque accru de
				 contracter la Covid-19, l’hygiène des mains joue un rôle essentiel dans la prévention des maladies
				 infectieuses.";
run;

ods region row=2;
title1 "Volumes par continent des pays retenus pour l'étude";
proc freq data=pays;
	table continent / nocum;
	footnote "Tout d’abord il est essentiel de définir le périmètre de notre étude. 
	Nous travaillons sur la période du 31 décembre 2019 au 02 novembre 2020. Nos données concernent 
	210 pays sur les 6 continents ci-dessus. Cette information est nécessaire pour pouvoir comparer 
	les continents dans nos analyses. Notons le nombre de pays officiellement reconnus par 
	l’Organisation des Nations Unies : ^n
	Pour l’Europe, la base de données compte 49 pays alors que l’ONU reconnaît uniquement 48 pays. 
	A l’inverse, L’ONU reconnaît 16 pays pour l’Océanie tandis que nos données en présentent 
	seulement 11. Pour l’Afrique, l’Amérique et l’Asie, l’ONU reconnaît 
	respectivement 54 pays, 35 pays et 47 pays ce qui ne correspond pas exactement à notre base de 
	données. ^n
	L’Afrique représente plus de 25% des pays observés et l’Europe 23%, soit près de la moitié des pays 
	étudiés.";
	/*AJOUTER UN TOTAL*/
run;
footnote;
title;
ods layout end;

title4 "Analyse des groupes de pays par nombre de morts";

ods layout gridded  width=60% columns=2;
ods region width=60%;
proc tabulate data=pays;
	class groupe_IHD groupe_deaths groupe_bed groupe_diab;
	table (groupe_deaths="Groupe de pays par nombre de morts"), 
		(groupe_IHD="Groupe par IDH") * (colpctn="% par colonne");
	table (groupe_deaths="Groupe de pays par nombre de morts"), 
		(groupe_bed="Groupe par nombre de lits par millier")* 
		(colpctn="% par colonne");
	table (groupe_deaths="Groupe de pays par nombre de morts"), 
		(groupe_diab="Groupe en fonction de la prévalence au diabète")* 
		(colpctn="% par colonne");
run;

ods region;
ods html text="^S={just=c font_size=9pt font_face=Arial}
	^n Quels sont les types de pays les plus fortement touchés par la Covid-19 ? ^2n
	Au début de la pandémie nous avons souvent entendu les médias qualifier ce virus d’une 
	maladie des “pays riches”, se demandant pourquoi le continent africain était si peu touché… ^2n
	Nous constatons en effet que parmi les pays ayant l’IDH le plus faible, environ 60% d’entre eux 
	se trouvent parmi les pays ayant eu le moins de morts par million d’habitants. À l’inverse, pour 
	le tiers des pays ayant les IDH les plus élevés, c’est plus de 50% d’entre eux qui sont parmi 
	les plus touchés en termes de nombre de morts, et près de 90 % d’entre eux se trouvent dans les 
	deux tiers les plus touchés. Alors certes nos chiffres confirment bien que “les Nords” sont 
	globalement plus fortement touchés par la Covid-19 que “les Suds”. ^3n
	Mais, cette différence d'exposition au coronavirus n’est pas la seule avoir été relevée par les 
	médias mondiaux. En effet, le manque de moyens des hôpitaux à été largement rappelé. En Europe et 
	principalement en France les conditions de travail du personnel soignant, le manque de lits etc. 
	ont été constamment dénoncés. La situation est de même aux Etat-Unis et en Amérique du Sud, qui 
	cumulent des débats sur la protection sociale. La capacité en termes de lits d'hôpitaux permet-elle 
	d’expliquer une différence entre les pays ? Il semblerait que la réponse soit plus contrastée. 
	Parmi les pays ayant le moins de lits par millier d'habitants, beaucoup font partie de ceux qui 
	ont un IDH faible (car il s’agit de pays financièrement plus pauvres), et comme nous l’avons montré 
	précédemment ces pays ont été moins impactés par la Covid-19. À l’inverse, pour les pays ayant le 
	plus de lits d'hôpitaux, environ 40 % d’entre eux font partie des pays ayant le plus de morts. 
	Ces chiffres montrent que même les pays ayant le plus de moyens ne sont pas épargnés. Ainsi, 
	l’augmentation des capacités d’accueil des hôpitaux seule ne permettrait pas réduire le taux de 
	mortalité. Cependant, nous verrons plus loin que par continent le nombre de lits par millier 
	d’habitants permet tout de même d’expliquer une différence d’impact en terme de taux de mortalité 
	des personnes infectées par le virus. ^3n";

ods layout end;

ods layout gridded width=70%;
ods region width=50%;
ods html text="^S={just=c font_size=9pt font_face=Arial}
	Est-il possible que la différence soit corrélée au nombre de personnes dont la santé est dite 
	“fragile” ? ^2n
	Prenons le cas du diabète. Les différences semblent être encore moins contrastées que précédemment.
	Néanmoins, parmi les pays ayant la plus faible part de prévalence au diabète, environ 37% d’entre 
	eux se trouvent parmi ceux ayant le moins de morts, et 31% parmi ceux ayant le plus de morts. 
	Or, il est évident que ces chiffres ne permettent pas de conclure. En effet, cette maladie chronique 
	est souvent associée aux pays riches. Ainsi, il faudrait pouvoir comparer le taux de mortalité des 
	personnes infectées du covid-19 des personnes ayant le diabète et de ceux qui ne l’ont pas, et les 
	données en notre possessions ne permettent pas ce calcul. De ce fait, nous pouvons supposer que 
	cette légère différence est en lien avec la première énoncé, ie: les pays riches ont été plus 
	fortement touchés probablement car plus exposés au tourisme de masse et aux phénomènes de 
	mondialisation plus généralement. ^2n
	Évidemment d’autres raisons ont été énoncées dans des articles de recherches ou dans les médias 
	mais elles ne peuvent être étudiées avec les données en notre possession. Il aurait été intéressant 
	de pouvoir étudier la différence liée à la capacité des pays à pouvoir tester leur population ou 
	bien celle liée à la part de la population ayant accès à des installations basiques de lavage de 
	mains mais la quantité d’information manquante par pays ne nous permet pas d’apporter des réponses 
	significatives.";
ods layout end;

ODS html text='<div align="center"> <input type="button" value="Retour"
         onclick="history.back()"></div>';
ODS HTML CLOSE;
title;
footnote;
ods _all_ close;

/**************** FIN DE LA PAGE INTRO ***************/
proc format;
	value casescolors low-<1000='DAGRY' 4000<-high="VIYPK";
	value deathscolors low-<5='DAGRY' 150<-high="VIYPK";
run;

/**************** PAGE PAYS ***************/
ods escapechar='^';
ODS HTML PATH="&chemin." (url='/folders/myfolders/SAS_M2_TIDE/EDC/PROJET/') 
	BODY='page_2.html' STYLE=htmlblue;
title j=center " ^S={preimage='Logo.png'} ";
TITLE2 h=24pt "ÉTUDE - COVID-19";
TITLE3 h= 20pt "La COVID-19 DANS LE MONDE";
ods layout gridded columns=2;
ods region width=50%;
title1 "Nombre de cas mensuel maximal de Covid-19 - (2020)";
%MAX_BY_MONTH(table_in=projet.covid, table_out=max_continent , nb=3, 
	var_use=total_cases total_cases_per_million new_cases_per_million);

proc report data=max_continent split="@" 		
		style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
		style(column)=[background=white fontsize=7pt];
	where mois ne .;
	define total_cases / "Nombre de cas total";
	define total_cases_per_million / "Nombre de cas @total par million" format=8.2;
	define new_cases_per_million / "Nombre de nouveaux @cas par million" 
		format=8.2 style={COLOR=casescolors. color=white };
	define Continent1-Continent3 / "Continent";
	define Pays1-Pays3 / "Pays";
run;

ods html text="^S={just=c font_size=9pt font_face=Arial}
	Quel est le bilan mensuel  en nombre de cas et décès de cette pandémie au cours de l’année 2020 ? ^3n
	Les statistiques confirment que la pandémie s’est d’abord développée en Chine. Aux mois de janvier 
	et février, la Chine présente le nombre de cas total infectés le plus important. Par la suite, la 
	pandémie a pris de l’ampleur sur le territoire Américain. Ainsi, depuis mars dernier les Etats-Unis 
	présentent le nombre de cas total d’infection le plus élevé chaque mois. ^3n
	Alors que la majorité des pays ont décidé de fermer certains établissements tels que les écoles, les 
	lieux de travail et les frontières internationales afin de limiter la propagation du virus lorsque 
	les cas de contamination covid19 ont commencé à être reportés aux quatre coins du globe, le nombre 
	de cas a continué à augmenter. En effet, rapporté par million, ce sont principalement les pays 
	d’Europe et d’Asie qui présentent un nombre de contamination le plus important sur l’ensemble de 
	la période 2020. Débutant en janvier par la Chine, elle atteint rapidement les pays voisins comme 
	la Corée du Sud qui devient en février le pays ayant le plus de cas en proportion de la population. 
	Les médias ont beaucoup parlé de la croissance exponentielle des cas en Chine, Italie, Brésil et  
	Etats-Unis. Pourtant en proportion à la taille de la population, le Qatar est le pays dont le bilan 
	est le plus lourd de juin à septembre. Bien que le pays soit 30 fois plus petit que l’Italie en termes 
	de population, les chiffres restent tout de même conséquents. ^3n
	En ce qui concerne le nombre de nouveaux cas annuels par million, le plus gros pic à été atteint au 
	Vatican, la première fois en mars et la seconde en octobre. Notons que le Vatican ne compte que 
	809 habitants. Ainsi, 1 cas de Covid-19 représente 1236.094 cas par million d'habitants. Au mois 
	d’octobre les 4944.38 cas par million d’habitants représentent en réalité 7 cas. En revanche, en 
	comparaison avec le Chili, le bilan est bien plus important. En effet, en juin le pays compte 1 892 
	nouveaux cas par million, alors que la population totale est de plus de 18 millions, ce qui se 
	traduit par plus de 6 000 nouveaux cas sur une journée de juin. C’est d’ailleurs à cette même période
	que le ministre de la santé chilien Jaime Mañalich démissionne.";

ods region width=50%;
title1 "Nombre de mort mensuel maximal lié au Covid-19 - (2020)";
%MAX_BY_MONTH(table_in=projet.covid, table_out=max_continent , nb=2, 
	var_use=total_deaths_per_million new_deaths_per_million);

proc report data=max_continent split="@" 		
		style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
		style(column)=[background=white fontsize=7pt];
	where mois ne .;
	define mois / "Mois";
	define total_deaths_per_million / "Nombre total de @morts par million" 
		format=8.2;
	define new_deaths_per_million / 
		"Nombre total de nouveaux @de morts par million" format=8.2 
		style={COLOR=deathscolors.}
		style(header)=HEADER{color=White};
	define Continent1-Continent2 / "Continent";
	define Pays1-Pays2 / "Pays";
run;
title;

ods html text="^S={just=c font_size=9pt font_face=Arial}
	En début de pandémie la Chine était évidemment également le pays avec le plus grand nombre de décès 
	covid19 étant le seul à être impacté. Cependant, depuis  le mois de mars c’est en Europe, à Saint-Marin (micro 
	Etat montagneux enclavé dans le centre-nord de l’Italie) que le nombre de décès liés au covid est le 
	plus important en rapportant par million. Or, sa population n’est que d’environ 34 000 habitants. 
	Ainsi, cela représente une cinquantaine de morts, ce qui suffit pour maintenir le pays comme celui 
	ayant le plus de morts par million de mars à octobre. Notons de plus que Saint-Marin n’a pas connu 
	de nouveaux décès liés au Covid-19 depuis mars. ^3n
	L’Europe et l’Amérique sont les continents avec les pics de nouveaux décès par million d’habitant le 
	plus important. En effet, au fil des mois, l’épidémie gagne du terrain sur la planète. En Amérique 
	du Sud, le maladie infectieuse renforce les inégalités sanitaires et sociales déjà très présentes. 
	En septembre 2020 le pic de nouveaux décès par million est atteint en Equateur. Près de 215 décès 
	par million, les services sanitaires et funéraires sont totalement débordés par l’afflux de milliers 
	de cadavres, les images de corps abandonnés dans les rues ont fait le tour du monde. De même, 
	quelques mois auparavant son grand voisin le Pérou et le Chili atteignent également les plus hauts 
	pics de mortalité sur les mois de juillet et juin respectivement. Tout l’Ouest de l’Amérique du Sud 
	face à une période difficile. ^3n
	Bien que l’Europe est rapidement devenue l’épicentre de l’épidémie où l’Italie a été très fortement 
	touchée lors du premier confinement avec un taux de mortalité très élevé, en proportion à la taille 
	de la population, ce n’est pas le pays qui a connu le plus grand pic.";

footnote;
ods layout end;

ods layout gridded width=70%;
ods region width=70%;
ods html text="^S={just=c font_size=12pt font_face=Arial}
	Devenu en quelques mois l’une des principales causes de mortalité à travers le monde, la covid19 
	a tué 1,2 million de personnes. Comment sommes nous arrivés à un tel bilan ?";
ods layout end;

/*Analyse des volumes et proportion à l'échelle mondiale (et vision par continent)*/
ods layout gridded columns=2 advance=bygroup;
ods graphics on /width=5in height=4in;
%BAR_MONTH_CONTINENT(nb=4, var_list=new_cases new_cases_per_million new_deaths 
	new_deaths_per_million);
ods layout end;

ods layout gridded width=70%;
ods region width=50%;
ods html text="^S={just=c font_size=9pt font_face=Arial}
	On voit une très nette croissance du nombre de nouveaux cas dans le monde au fil des mois, avec une 
	certaines stagnations autour du mois d'août et septembre qui correspond pourtant à une période où 
	beaucoup de pays n’étaient plus confinés. En France, par exemple a cette période le masque n’était 
	pas encore obligatoire pour pouvoir circuler en extérieur et les restaurants avaient également 
	rouverts. La raison de ce ralentissement peut être lié à la météo. Les activités se font plus 
	généralement en extérieur ce qui favorise le renouvellement de l’air ambiant. De même, à cette 
	période les frontières de beaucoup de pays étaient ouvertes. Notons également que la forte progression 
	du nombre de nouveaux cas peut également s’expliquer par l’augmentation du nombre de personnes testé. 
	Ainsi, il faudrait pouvoir étudier le taux de positivité au test. Or, par soucis lié aux valeurs 
	manquantes nous ne pouvons pas étudier cette information. ^3n
	Ainsi, le mois d’octobre est celui qui comptabilise le plus de nouveaux cas avec une moyenne de plus 
	de 10 000 cas. De plus, cette moyenne est largement supporté par l’Amérique du Sud et l’Europe. 
	L’Amérique du Sud reste le continent le plus touché sur les 6 derniers mois. ^2n
	En revanche, lorsqu’il s’agit du nombre de nouveaux cas moyen par million, la croissance mondiale 
	est plus progressive et stagne même sur le fin de la première vague entre avril et mai, et augmente 
	de manière exponentielle en octobre. Autre fait surprenant, lorsqu’on ramène en million d’habitants 
	on remarque que les nouveaux cas viennent principalement de l’Europe et de l’Océanie en octobre. ^2n
	En termes de nombre de décès journalier moyen liés au covid19, le mois d'août est celui qui se révèle 
	le plus meurtrier. Alors qu’en nombre de nouveaux de cas journalier moyen il représentait un mois de 
	stagnation de l’évolution. Ainsi, il faudrait pouvoir étudier le taux de mortalité des personnes 
	infectées du Covid-19. Cette analyse sera faite ultérieurement dans une analyse par continent. 
	Une fois encore l’Amérique du Sud concentre plus de 50% du nombre de nouveaux morts journalier moyen 
	sur la période de juin à octobre, suivis de l’Amérique du nord qui en représente environ 20%. ^3n
	En proportion à la population, le pic apparaît plutôt en septembre au début de la seconde vague, et 
	on remarque également un pic bien marqué au mois d’avril principalement soutenue par les pays européens.";
ods layout end;

ODS html text='<div align="center"> <input type="button" value="Retour"
         onclick="history.back()"></div>';
ODS HTML CLOSE;

/*********** FIN DE PAGE ***********/


/*  FIN DE L'ANALYSE DESCRIPTIVE  */
/*_____________________________________________________________________________________________________________________*/
/*_____________________________________________________________________________________________________________________*/
/*                                                             REPORTING PAR CONTINENT                                                             */
/*_____________________________________________________________________________________________________________________*/
/*Calcul du taux de mortalité possible (il est fait ci-dessous) mais le calcul du taux de positivité (nbr de cas / nbr de test) n'est pas significatif car nous avons l'info pour seulement 44 pays.*/
proc format;
	value percentcolors low-<2='DAGRY' 2.5<-4='Salmon' 4<-high="VIYPK";
	value gras 4<-high='bold';
	value monthspercentcolors low-<2.5='DAGRY' 3.5<-5='Salmon' 5<-high="VIYPK";
	value monthsgras 5<-high='bold';
run;

ODS HTML PATH="&chemin." (url='/folders/myfolders/SAS_M2_TIDE/EDC/PROJET/') 
BODY='continents.html' STYLE=htmlblue;
title j=center " ^S={preimage='Logo.png'} ";
TITLE2 h=24pt "ÉTUDE - COVID-19";
title3 h=16pt "REPORTING PAR CONTINENT";



ods layout gridded columns=2 advance=bygroup;
ods graphics on /width=5in height=4in;
%GRAPH_TIME(table_in=projet.covid, var_use=total_cases_per_million);
%GRAPH_TIME(table_in=projet.covid, var_use=total_deaths_per_million);
ods layout end;

ods layout gridded width=70%;
ods region width=60%;
ods html text="^S={just=c font_size=9pt font_face=Arial}
	Débutons notre analyse par continent par une vision d’ensemble moyenne mettant en avant l’évolution 
	de l’épidémie de Covid-19 en nombre de cas total (par million) et le nombre de décès total (par million). 
	Pour des raisons d’échelle, on ne voit pas de manière détaillée le début de la pandémie. Cependant, 
	on remarque clairement que la pandémie a pris de l’ampleur sur tous les continents vers mi-mars et 
	début avril, où la courbe de l’Europe croît fortement. En effet, sur la période de mars l’Italie 
	enregistre plus de 7000 morts et la France franchit le cap 1000 morts par jour à cette même période. ^3n
	Par la suite, les chiffres de l’Europe se sont stabilisés suite à la mise en place des confinements 
	dans les différents pays aux mois de mars, avril et mai. Cependant, en parallèle la pandémie éclate 
	sur le territoire Américain. L’Amérique du Sud a connu une croissance exponentielle du nombre de 
	cas et de mort. ^3n
	Bien que la situation se soit stabilisée sur le territoire européen depuis mai, le mois de septembre 
	s’accompagne d’une reprise de la croissance avec les rentrées scolaires. De ce fait, l’Europe rattrape 
	même l’Amérique du Sud en termes de cas total confirmé, entraînant un second confinement pour beaucoup 
	de pays. ^2n
	Cependant, même si le nombre de cas total entre ces deux continents est assez proche, en ce qui 
	concerne le nombre de décès, l'Europe a su maintenir sa courbe, bien qu’elle soit tout de même 
	au-dessus de la moyenne mondiale. ^2n
	L'Océanie, comme l’Europe, a été stable sur une longue période puis a connu une croissance accélérée 
	sur le nombre de cas infectés au mois de fin août et début septembre, mais le nombre de morts n’a pas 
	pour autant augmenté de manière aussi significative. ^2n
	L’Afrique présente le bilan le plus léger parmi tous les continents, ce qui rejoint le point énoncé 
	dans la première partie de l’article qui disait que le Covid-19 impact moins  «Les Suds ».";
ods layout end;




title1  height=18pt justify=left bold color=DAGB "Les caractéristiques des continents";
title2 height=8pt color=DAGB "Les continents ayant le plus de pays avec IDH élévé";
%transfo_crossfreq(var=groupe_IHD ,var2=continent);
ods layout gridded width=70%;
ods region width=60%;

proc report data=freq_tab 
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
columns _all_;
define groupe_IHD / group "Groupe de pays par IDH";
run;
title1;

title2 height=8pt color=DAGB "Les continents ayant le plus de morts (par millions d'habitants)";
%transfo_crossfreq(var=groupe_deaths ,var2=continent);
proc report data=freq_tab 
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
columns _all_;
define groupe_deaths/ group "Groupe de pays par nombre de morts";
run;


title2 height=8pt color=DAGB "Les continents ayant le plus de lits (par millier d'habitants)";
%transfo_crossfreq(var=groupe_bed ,var2=continent);
proc report data=freq_tab 
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
columns _all_;
define groupe_bed / group "Groupe de pays par nombre de lits";
run;

title2 height=8pt color=DAGB "Les continents ayant la plus forte prévalence de diabète";
%transfo_crossfreq(var=groupe_diab ,var2=continent);
ods layout gridded width=70%;
ods region;
proc report data=freq_tab 
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
columns _all_;
define groupe_diab/ group "Groupe de pays par prévalence de diabète";
run;



ods region width=40%;
ods html text="^S={just=c font_size=9pt font_face=Arial}
	En début d’article nous avons présenté les caractéristiques des pays les plus touchés par le virus. 
	Puisque nous travaillons à présent à l'échelle des continents, il est légitime de présenter pour 
	chaque continent ses caractéristiques. En terme d’IDH, 80% des pays africains sont parmi les pays 
	ayant le plus faible IDH. Rappelons que les graphiques et tableaux précédents ont permis de mettre 
	en évidence que l’Afrique est le continent qui a été le moins touché. Le fait que les échanges 
	commerciaux et touristiques soient moins importants avec l’Afrique a permis au continent de 
	réduire son exposition. À l'inverse, 85% des pays Européens font partie des pays aux IDH les plus élevés. ^n
	En terme de  nombre de morts, plus de  60% des pays européens, et plus de 75% des pays d'Amérique latine 
	font partie du tiers des pays ayant le plus de morts par million d’habitants. ^2n
	Qu'en est-il de la capacité d'accueil de ces continents ? ^n
	Rappelons que l’Europe est l’un des continents où le nombre de morts par millions d’habitants est le plus élevé… 
	On constate pourtant que 78 % des pays européens font partie des pays ayant le plus de lits par millier et aucun 
	d’eux n’appartient au groupe de pays ayant le moins de lits. Au contraire, l'Amérique du Sud à une capacité 
	d'accueil très faible. En effet, nous l'avons énoncé précédemment pour l’Equateur. Les résultats ci-contre permettent 
	de le confirmer : seulement 8% des pays d’Amérique du Sud font partie des pays ayant le plus de lits. L’écart de 
	moyens entre les pays d’Europe et d’Amérique du Sud est conséquent alors que le bilan en nombre de cas et de morts 
	n’est pas aussi contrasté en proportion. ^2n
	Pour finir, la forte prévalence du diabète est très marquée en Amérique du nord, où 70% des pays font partie de 
	ceux ayant la plus forte prévalence. De même, pour l’Océanie où ce pourcentage s'élève à plus de 77%. Nous verrons 
	dans la suite l’utilité de ces résultats.";
ods layout end;





title "Mortalité mensuelle lié au Covid-19 par continent - (2020)";
ods layout gridded width=70%;
ods region;
proc report data=projet.covid (where=(mois < 11 and continent ne "World")) 
		split="@" 		
		style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
		style(column)=[background=white fontsize=7pt];
	column mois continent, (total_deaths_per_million deaths_per_cases=moyenne);
	define mois / ORDER ORDER=INTERNAL "Mois" group style={fontsize=8pt};
	define continent / across "Mortalité mensuelle lié au Covid-19 par continent";
	define total_deaths_per_million / sum 'Nbr de mort total (par million)' 
		format=8.2;
	define moyenne / mean '% de mortalité moyen @ des personnes infecté du covid' 
		format=6.2 
		style={COLOR=monthspercentcolors. font_weight=monthsgras.}
		style(header)=HEADER{color=White};
	rbreak after/summarize style={font_weight=BOLD fontsize=8pt};
run;




ods region width=40%;
ods html text="^S={just=c font_size=9pt font_face=Arial} 
	La connaissance des caractéristiques des continents étant faite, ainsi que leur bilan en terme de nombre de morts et 
	de nombre de cas ; un nouvel indicateur essentiel peut-être introduit : le pourcentage de mortalité des personnes infectées 
	par le virus. ^n
	À défaut de pouvoir étudier le taux de positivité des tests ou la part de personnes ayant accès à des installations de lavages 
	de mains, ce nouvel indicateur peut nous permettre de mieux comprendre l’impact de la capacité d’accueil des hôpitaux. En effet, 
	la mortalité de ce virus est accrue lorsqu’il touche des pays qui combinent un grand nombre de cas et peu de lits d'hôpitaux. 
	Nous pouvons à présent comparer les continents en proportion de leur nombre de cas. ^3n
	Le plus fort pourcentage de mortalité lié au virus est atteint en Amérique du Nord au mois de mai. C’est d'ailleurs le deuxième continent 
	où la mortalité en proportion des personnes infectées est la plus élevée. Or, on rappelle que 40% des pays d’Amérique du Nord ont très 
	peu de lit, et 70% ont une part élevée de prévalence au diabète. ^2n
	L’Europe est encore en tête… C’est le continent où le pourcentage de mortalité est le plus élevé (3,88%) en moyenne par jour sur toute 
	la période considérée, avec un pic atteint en mai-juin où plus de 5 patients infectés par le virus sur 100 qui décèdent par jour. ^2n
	A contrario, l’Amérique du Sud parvient à stabiliser ce pourcentage, bien que le nombre de cas augmente de manière exponentielle comme 
	nous l’avons vu dans les graphiques précédents. En moyenne sur l’ensemble de la période 3.3% patients infectés par le virus décèdent par jour. ^2n
	Malgré un début moins progressif que les autres, l’Afrique a rapidement maîtrisé le nombre de cas et de décès. Ainsi, pour 100 personnes 
	infectées par le virus 2.73 d’entre elles décèdent en moyenne. ^2n
	Certains pays comme la Chine, considèrent que les différentes saisons ont un impact différent sur la pandémie. En prenant par exemple 
	le discours prononcé récemment par ZHANG BOLI, un spécialiste de la médecine en Chine, qui annonce des restrictions sur les déplacements 
	et les regroupements sur le territoire chinois en raison de la saison. Selon lui, le froid est très approprié pour la survie du virus. 
	Du point de vue statistique, le pic de mortalité en Asie est atteint en février (3,06%) , et qui par la suite est plus ou moins stable 
	(entre 2,10% et 2,18%). ^n
	A travers les médias, nous savons que la Chine n'enregistre plus de nouveau cas, ou seulement des cas provenant de l'extérieur. Récemment 
	de nouveaux cas ont été enregistrés sur le territoire. Tous les pays n'adoptent pas la même vision que la Chine comme les Etats-Unis où 
	Donald TRUMP qui ne soutient pas du tout  cette hypothèse. De plus, selon l'OMS, aucun signe montre que la maladie est saisonnière. 
	Ceci peut être compréhensif lorsque l'on regarde les statistiques sur les autres continents tels que l'Europe ou l'Amérique du Nord où la 
	mortalité reste très élevée sur les différents mois de l'année.";
ods layout end;




title "Mortalité lié au Covid-19 par continent en fonction du nombre de lits - (01/11/2020)";
ods layout gridded width=70%;
ods region;
proc report data=pays split="@"
		style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
		style(column)=[background=white fontsize=7pt];
	column continent groupe_bed, (total_deaths_per_million 
		deaths_per_cases=moyenne);
	define continent / "Continents" group style={fontsize=8pt};
	define groupe_bed / across 
		"Groupe de pays par continent selon le nombre de lits";
	define total_deaths_per_million / sum 'Nbr de mort total @ (par million)' 
		format=6.2;
	define moyenne / mean '% de mortalité moyen des @personnes infecté du covid' 
		format=6.2 
		style={COLOR=percentcolors. font_weight=gras.}
		style(header)=HEADER{color=White};
	rbreak after/summarize style={font_weight=BOLD fontsize=8pt};
	compute after;
		Continent="World";
	endcomp;
run;
title;

ods region width=40%;
ods html text="^S={just=c font_size=9pt font_face=Arial} 
	La part de mortalité des personnes infectées du covid et le nombre de lits d’hôpitaux sont-ils liés ? ^3n
	Suite à l’expansion de la pandémie, un des sujets qui apparaît souvent dans les médias est le manque de matériel, de personnel 
	et de lit dans les hôpitaux. Certains pays comme la Chine et l’Italie ont été amenés à construire des hôpitaux temporaires pour 
	traiter des patients infectés par le coronavirus. Ainsi, cette partie est consacrée au lien entre ce sujet et  notre indicateur 
	de mortalité. ^2n
	À l’échelle mondiale (World), pour 100 patients infectés par le virus, 2.90 d’entre eux décéderont en moyenne dans les pays ayant 
	le moins de lits par millier, contre 1.59  dans les pays ayant le plus de lits. ^2n
	Pour chaque contient hormis l’Océanie, ce pourcentage augmente quand le nombre de lits est plus faible. C’est en Amérique du Sud 
	dans les pays où le nombre de lits est le plus faible que ce pourcentage est le plus élevé (4,19 %). ^3n
	Notons, que précédemment nous avions souligné que près de 80% des pays d’Europe étaient dans le groupe des pays les mieux munis en 
	termes de lit et que le nombre de morts était également parmi les plus élevés. À présent, nous constatons que parmi les pays ayant 
	le plus de lits ceux présents en Océanie présentent le pourcentage de mortalité le plus élevé alors que dans le tableau précédent 
	qui indique la mortalité mensuelle, ce n’est pas le continent au plus fort pourcentage de mortalité. Ainsi, lorsqu’on compare les 
	continents en fonction par tranche en fonction de leur capacité d'accueil hospitalière, c'est l’Océanie (3,29%) et L’Amérique du Sud 
	qui présentent le plus fort pourcentage de mortalité par personne infectée. ^3n
	De manière très claire, le pourcentage de mortalité des personnes infectées du Covid-19 augmente lorsque le nombre de lit diminue. 
	Le manque de lit pourrait dans ce cas expliquer une partie du nombre total de mort et de la mortalité élevé.";
ods layout end;


ods region width=40%;
ods html text="^S={just=c font_size=9pt font_face=Arial} 
	Des études sont portées sur le covid-19, les résultats montrent que les personnes âgées, les plus démunies, et celles sujettes à des 
	diabètes non contrôlés ou à des asthmes sévères font partie des populations les plus à risque. ^n
	Les données ci-desous vont en effet dans le sens de ces études.";
ods layout end;

PROC SQL NOPRINT; /* Proc SQL pour récupérer le max des moyennes des différents variables */
	SELECT round(MAX(MEAN_T), 0.01), round(MAX(MEAN_T2), 0.01), round(MAX(MEAN_T3), 0.01)
	/* Sélectionne le max des variables (MEAN_T,MEAN_T2,MEAN_T3 )arrondi à 2 chiffres après la virgule */

	INTO :max_test, :max_test2, :max_test3
	/* Insère le max  des variables dans   :max_test, :max_test2, :max_test3 */

	FROM (SELECT MEAN(deaths_per_cases) as MEAN_T, MEAN(hospital_beds_per_thousand) as MEAN_T2,
		  MEAN(diabetes_prevalence) as MEAN_T3
		FROM PROJET.COVID WHERE continent NE "WORLD"
		GROUP BY CONTINENT);
	/* Selectionner la moyenne des variables deaths_per_cases,hospital_beds_per_thousand et diabetes_prevalence et définir en tant que MEAN_T,MEAN_T2,MEAN_T3 respectivement
		à partir de la table projet.covid sous condition que la variable continent ne contient pas la catégorie "WORLD" et grouper par continent
		Ainsi nous avons le maximum de la moyenne des variables deaths_per_cases,hospital_beds_per_thousand et diabetes_prevalence par continent 
		qui est stocké dans :max_test, :max_test2, :max_test3 et qui pourra être appelé plus tard dans la proc report */
QUIT;
PROC SQL NOPRINT; /* Proc SQL pour récupérer le min des moyennes des différents variables */
	SELECT round(MIN(MEAN_T), 0.01), round(MIN(MEAN_T2), 0.01), round(MIN(MEAN_T3), 0.01)
	/* Sélectionne le min des variables (MEAN_T,MEAN_T2,MEAN_T3 )arrondi à 2 chiffres après la virgule */
	INTO :min_test, :min_test2, :min_test3
	/* Insère le min  des variables dans   :min_test, :min_test2, :min_test3  */
	FROM (SELECT MEAN(deaths_per_cases) as MEAN_T, MEAN(hospital_beds_per_thousand) as MEAN_T2,
		  MEAN(diabetes_prevalence) as MEAN_T3
		FROM PROJET.COVID WHERE continent NE "World"
		GROUP BY CONTINENT);
	/*  Selectionner la moyenne des variables deaths_per_cases,hospital_beds_per_thousand et diabetes_prevalence et définir en tant que MEAN_T,MEAN_T2,MEAN_T3 respectivement
		à partir de la table projet.covid sous condition que la variable continent ne contient pas la catégorie "WORLD" et grouper par continent
		Ainsi nous avons le min de la moyenne des variables deaths_per_cases,hospital_beds_per_thousand et diabetes_prevalence par continent */

QUIT;

title;

/*  Proc report pour résumer les proc freq réalisés précédement sur les caractéristiques des continents au niveau des deaths_per_cases,
hospital_beds_per_thousand et diabetes_prevalence. Indique la moyenne par continent, en rouge représentera le maximum 
en vert le minimum pour chaque variable et pour chaque continent  */
title2 "Résumé des trois indicateurs précédents";
ods layout gridded width=70%;
ods region;
proc report data=PROJET.COVID split='@'
style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
		style(column)=[background=white fontsize=7pt];
where continent ne "World"; /*  Condition: Continent différent de "World"  */
column continent 
deaths_per_cases
hospital_beds_per_thousand
diabetes_prevalence
; /*  Colonne selectionné qui vont apparaître dans la proc report  */
define continent / ORDER ORDER=INTERNAL "Continent" group style={fontsize=8pt};
	/*  grouper et trier continent dans l'ordre alphabétique  */
define deaths_per_cases / MEAN  "Nombre de lits"  format=6.2 style={fontsize=8pt}; 
	/* définis la variable deaths_per_cases, on prend sa moyenne  */
	compute deaths_per_cases ;
	   if round(deaths_per_cases.mean, 0.01)  = &max_test. then
	        call define(_COL_,"style","style={color=VIYPK}");
		/*  Si la variable deaths_per_cases arrondi à 2 chiffres après la virgule est égale au &max_test. définis précédement dans la 
			proc sql qui correspond au maximum de la moyenne de la variable par continent alors on applique call define avec
			en argument 1 qui indique la cellule à impacter, en second argument qui identifie l'attribut à définir et donc ici le style
			et en troisième argument qui fournit la valeur de l'attribut qui ici indique la cellule de prendre le style couleur vert  */
		if round(deaths_per_cases.mean, 0.01)  = &min_test. then
	        call define(_COL_,"style","style={color=DAGRY}");
		/* Si la variable est égale au &min_test. alors il sera marqué en vert */
	endcomp;

define hospital_beds_per_thousand / MEAN "Nombre de lits" format=6.2  style={fontsize=8pt};
	compute hospital_beds_per_thousand ;
	   if round(hospital_beds_per_thousand.mean, 0.01)  = &max_test2. then
	        call define(_COL_,"style","style={color=VIYPK}");
		if round(hospital_beds_per_thousand.mean, 0.01)  = &min_test2. then
	        call define(_COL_,"style","style={color=DAGRY}");

	endcomp;

define diabetes_prevalence / MEAN "Prevalence de diabete" style={fontsize=8pt};
	compute diabetes_prevalence ;
	   if round(diabetes_prevalence.mean, 0.01)  = &max_test3. then
	        call define(_COL_,"style","style={color=VIYPK}");
		if round(diabetes_prevalence.mean, 0.01)  = &min_test3. then
	        call define(_COL_,"style","style={color=DAGRY}");
	endcomp;
run;

ods region width=40%;
ods html text="^S={just=c font_size=9pt font_face=Arial} 
	Le nombre de mortalité lié au covid par continent est très élevé en Amérique du Nord, cela pourrait être dû au faible nombre de lits 
	à disposition et d’une part assez importante (10%) de la population qui est diabétique. ^2n
	L’Europe, bien qu’on a beaucoup entendu parler d’un manque de lits, d’équipements, d’effectifs pendant le confinement, reste le continent 
	avec la meilleure capacité d’accueil hospitalier. Cependant, le taux de mortalité reste l’un des plus importants (4,4%). ^2n
	D’autre part, 15,3% de la population de l’Océanie est diabétique donc plus à risque face à la covid. Est-ce cette inquiétude légitime face 
	à cette avancée de l’épidémie qui les a poussés à redouter de vigilance et a permis de limiter la propagation de ce dernier ?  ^2n
	Comme on l’a vu précédemment, l’Afrique reste relativement épargnée par cette épidémie avec un taux de mortalité assez faible (3,17%) 
	alors que c’est le continent avec le système sanitaire le plus défaillant. ^2n
	Enfin, c’est en Asie que la covid19 a été la moins meurtrière avec en moyenne 2,59% de mortalité sur l’ensemble de la période. 
	Cela est particulièrement frappant car certains pays comme le Japon, qui présente de nombreuses conditions qui le rendent vulnérable 
	(maladie qui tue principalement les personnes âgées et qui est massivement amplifiée par les foules) n’ont jamais adopté l'approche 
	de lutte contre le virus que certains de ses voisins ont adoptée, et pourtant s’en est très bien sorti.";
ods layout end;


footnote;


title "Mortalité lié au Covid-19 par continent de la part de la population âgée de plus de 70ans - (01/11/2020)";
ods layout gridded width=70%;
ods region;
proc report data=pays split="@"
		style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
		style(column)=[background=white fontsize=7pt];
	column continent group_70, (total_deaths_per_million deaths_per_cases=moyenne);
	define continent / "Continents" group style={fontsize=8pt};
	define group_70 / across "Groupe de pays par continent selon la part de @ la population âgée de plus de 70 ans";
	define total_deaths_per_million / sum 'Nbr de mort total @ (par million)' 
		format=6.2;
	define moyenne / mean '% de mortalité moyen des @personnes infecté du covid' 
		format=6.2 
		style={COLOR=percentcolors. font_weight=gras.}
		style(header)=HEADER{color=White};
	rbreak after/summarize style={font_weight=BOLD fontsize=8pt};
	compute after;
		Continent="World";
	endcomp;
run;

ods region width=40%;
ods html text="^S={just=c font_size=9pt font_face=Arial} 
	Quelle est la situation de cette pandémie chez les personnes âgées ? ^n
	Les personnes âgées sont les premières victimes de cette pandémie COVID-19. Les décomptes dans les maisons de retraite ne cessent 
	d’augmenter. ^2n
	Le résultat ci-dessus ne permet pas de visualiser l’idée pour les continents comme l’Afrique, l’Asie où le nombre total de morts est 
	plus important dans les pays où la part des personnes âgées de plus de 70 ans est la plus faible. De plus, en Europe, tous les pays 
	observés font partie de ceux qui ont la plus grande part de la population âgée de plus de 70 ans. Cependant, pour l’Amérique du Nord, 
	l’Amérique du Sud, et l’Océanie, le nombre de décès est plus important parmi les pays où la part des personnes âgées de plus de 70 ans 
	est la plus grande. ^n
	On remarque aussi que l’Amérique présente un taux de mortalité très élevé pour les personnes âgées de plus de 70 ans. 
	Ce qui confirme que les personnes âgées sont plus touchées par cette maladie. Ce qui rejoint en partie l’idée de l’article publié par 
	l’ONU en avril 2020, qui confirme que pour les États-Unis, 80% des décès dus à la COVID-19 enregistrés à la mi-mars touchaient des 
	personnes âgées de 65 ans et plus. ^4n
	En conclusion l'Amérique latine a été plus sévèrement touchée par l'épidémie. C'est également l'un des continents les plus fragiles en 
	matière de moyen financier et sanitaire. Pourtant face à la violence de l'épidémie il a su maintenir son nombre de morts en proportion 
	au nombre des cas. À l'inverse l'Europe, et l'Océanie sont les continents qui ont le moins bien géré la crise lorsque l'on compare les 
	pays avec les mêmes moyens. ";
ods layout end;



ODS html text='<div align="center"> <input type="button" value="Retour"
         onclick="history.back()"></div>';


ODS HTML CLOSE;
ods _all_ close;









/*************  LE POWERPOINT   *********/



ods powerpoint file="&chemin/PROJET_SAS_GROUPE1.pptx";
options orientation=landscape nodate papersize=(10in 5.5in) ;
ods escapechar='~';
footnote1 '~{style [fontsize=20pt color=DAGB] _____________________________ }' 
'~{style [fontsize=8pt color=DAGB] Groupe 1 - Mardi 5 janvier 2021}';

ods powerpoint options(backgroundimage="&chemin/image.jpg");
ods powerpoint layout=TitleSlide;
proc odstext;
	p "Étude de cas SAS" / style=PresentationTitle[color=White];
	p "La Covid-19 dans le monde" / style=PresentationTitle2[color=White];
	p "M2 TIDE - Université Paris 1 Panthéon-Sorbonne" /style=[just=c fontsize=12pt color=White];
run;


ods powerpoint layout=TitleSlide;
proc odstext;
	p "Plan" / style=[just=c fontsize=30pt color=White];
	p "Organisation" / style=[just=l fontsize=20pt color=White];
	p "Contexte & Analyse à l'echelle mondiale" / style=[just=l fontsize=20pt color=White];
	p "L'impact a-t-il été le même pour chaque continent ?" /style=[just=l fontsize=20pt color=White];
run;

ods powerpoint layout=_null_ image_dpi=1000 options(backgroundimage="&chemin/fond.jpg");
title1 height=18pt justify=left bold color=DAGB " I. Contexte de l'Étude ";
title3 height=8pt bold color=DAGB "Situation à l'échelle mondial du Covid-19 - (01/11/2020)";
ods layout gridded ;
proc report data=projet.covid split='@'
style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
style(column)=[background=white fontsize=7pt];
where location="World" and date = mdy(11,01,2020) ;
column total_cases total_deaths population median_age handwashing_facilities;
define total_cases / CENTER "Nombre total de cas";
define total_deaths / CENTER "Nombre total de morts";
define population / CENTER "Population totale";
define median_age / CENTER "Age médian";
define handwashing_facilities / CENTER "Part de la pop. ayant accès à @ des instalations de lavage de mains";
run;

ods exclude all;
ods output onewayfreqs=freq_pays (drop=table continent);
proc freq data=pays;
table continent / nocum;
run;
ods output clear;
ods exclude none;

title5 height=8pt bold color=DAGB "Volumes des continents étudiés";
proc report data=freq_pays
style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
style(column)=[background=white fontsize=7pt];
run;
ods layout end;

/*Nb cas mensuel max*/
ods powerpoint layout=null;
title1 height=18pt justify=left bold color=DAGB  "Nombre de cas mensuel maximal de Covid-19 - (2020)";
title2 " ";
%MAX_BY_MONTH(table_in=projet.covid, table_out=max_continent ,nb=3,var_use=total_cases total_cases_per_million new_cases_per_million );
proc report data=max_continent split="@"
style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
style(column)=[background=white fontsize=7pt];
where mois ne .;
define mois/ "Mois" style={fontsize=7pt font_weight=bold};
define total_cases / "Nombre de cas total" style={fontsize=7pt};
define total_cases_per_million / "Nombre de cas @total par million" format=8.2 style={fontsize=7pt};
define new_cases_per_million / "Nombre de nouveaux @cas par million" format=8.2 style={COLOR=casescolors. fontsize=7pt}
	style(header)=HEADER{color=White};
define Continent1-Continent3 / "Continent" style={fontsize=7pt};
define Pays1-Pays3 / "Pays" style={fontsize=7pt};
run;


/*Nb morts mensuel max*/
title1 height=18pt justify=left bold color=DAGB "Nombre de mort mensuel maximal lié au Covid-19 - (2020)";
title2 " ";
 %MAX_BY_MONTH(table_in=projet.covid, table_out=max_continent ,nb=2, var_use=total_deaths_per_million new_deaths_per_million);
proc report data=max_continent split="@"
style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
style(column)=[background=white fontsize=7pt];
where mois ne .;
define mois/ "Mois" style={fontsize=7pt font_weight=bold};
define total_deaths_per_million / "Nombre total de @morts par million" format=8.2 ;
define new_deaths_per_million / "Nombre total de nouveaux @ morts par million" format=8.2 style={COLOR=deathscolors. fontsize=7pt }
		style(header)=HEADER{color=White}; 
define Continent1-Continent2 / "Continent" style={fontsize=7pt};
define Pays1-Pays2 / "Pays" style={fontsize=7pt};
run;
title;


ods powerpoint layout=_null_ image_dpi=500;
ods graphics on /width=7.5in height=5in;
title1 height=15pt justify=left bold color=DAGB  "Nombre de nouveaux cas mensuel moyen - 2020";
title2 " ";
PROC SGPLOT DATA =projet.covid (where=(mois < 11  and continent ne "World"));
styleattrs datacolors=(purple GRGY STGY  PAV  STPK LIOY) backcolor=White  /*wallcolor=BIGB*/;
VBAR mois/response=new_cases stat=mean  group=Continent barwidth=.5 seglabel transparency=0.3 DATASKIN=PRESSED;
keylegend / location=inside position=topleft across=1;
yaxis label='Nombre de nouveaux cas mensuel moyen' labelattrs=(color=BIGB weight=bold) valueattrs=(color=BIGB );
xaxis label="Mois" labelattrs=(color=BIGB weight=bold) valueattrs=(color=BIGB ) FITPOLICY=None;
RUN;


ods powerpoint layout=_null_ image_dpi=500;
title1 height=15pt justify=left bold color=DAGB  "Nombre de nouveaux cas mensuel moyen par million d'habitants - 2020";
title2 " ";
PROC SGPLOT DATA =projet.covid (where=(mois < 11  and continent ne "World"));
styleattrs datacolors=(purple GRGY STGY  PAV  STPK LIOY) backcolor=White  /*wallcolor=BIGB*/;
VBAR mois/response=new_cases_per_million stat=mean  group=Continent barwidth=.5 seglabel transparency=0.3 DATASKIN=PRESSED;
keylegend / location=inside position=topleft across=1;
yaxis label='Nombre de nouveaux cas mensuel moyen' labelattrs=(color=BIGB weight=bold) valueattrs=(color=BIGB );
xaxis label="Mois" labelattrs=(color=BIGB weight=bold) valueattrs=(color=BIGB ) FITPOLICY=None;
RUN;
title1;
title2;


ods powerpoint options(backgroundimage="&chemin/image.jpg");
ods powerpoint layout=TitleSlide;
proc odstext;
	p "L'impact a-t-il été le même pour chaque continent ?" / style=PresentationTitle[color=White];

run;


ods powerpoint layout=_null_ options(backgroundimage="&chemin/fond.jpg");
title1  height=18pt justify=left bold color=DAGB "Les caractéristiques des continents";
ods layout gridded ;
%transfo_crossfreq(var=groupe_bed ,var2=continent);
title2 height=8pt color=DAGB "Les continents ayant le plus de lits (par millier d'habitants)";
proc report data=freq_tab 
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
columns _all_;
define groupe_bed / group "Groupe de pays par nombre de lits";
run;


title1 " ";
title2 height=8pt color=DAGB "Les continents ayant la plus forte prévalence de diabète";
%transfo_crossfreq(var=groupe_diab ,var2=continent);
proc report data=freq_tab 
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
columns _all_;
define groupe_diab/ group "Groupe de pays par prévalence de diabète";
run;
ods layout end;

ods powerpoint layout=_null_;
title1 height=18pt justify=left bold color=DAGB "Mortalité mensuelle lié au Covid-19 par continent - (2020)"; 
proc report data=projet.covid (where=(mois < 11 and continent ne "World")) split="@"
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
column  mois continent, (total_deaths_per_million deaths_per_cases=moyenne);
define mois / ORDER ORDER=INTERNAL "Mois" group ;
define continent / across " "; /*Pour bien rentrer dans la diapo*/
define total_deaths_per_million / sum 'Nbr de mort total (par million)' format=8.2;
define moyenne / mean '% de mortalité moyen du Covid-19' format=6.2  
	style={COLOR=monthspercentcolors. font_weight=monthsgras.}
	style(header)={color=WHITE};
rbreak after/summarize 
	style={font_weight=BOLD};
run;


ods powerpoint layout=_null_;
title1 height=18pt justify=left bold color=DAGB "Mortalité lié au Covid-19 par continent en fonciton du nombre de lits ";
title2 height=10pt color=DAGB "(01/11/2020)";
proc report data=pays split="@"
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
column continent  groupe_bed, (total_deaths_per_million deaths_per_cases=moyenne);
define continent / "Continents" group style={fontsize=8pt};
define groupe_bed / across "Groupe de pays par continent selon le nombre de lits";
define total_deaths_per_million / sum 'Nbr de mort total @ (par million)' format=6.2;
define moyenne / mean '% de mortalité moyen des @personnes infecté du covid' format=6.2  
	style={COLOR=percentcolors. font_weight=gras.}
	style(header)={color=WHITE};
rbreak after/summarize 
	style={font_weight=BOLD fontsize=8pt};
compute after ;
Continent="World";
endcomp;
run;

ods powerpoint layout=_null_;
title1 height=18pt justify=left bold color=DAGB "Mortalité lié au Covid-19 par continent de la part de la population âgée de plus de 70ans ";
title2 height=10pt color=DAGB "(01/11/2020)";
proc report data=pays split="@"
	style(header)=HEADER{backgroundcolor=BIGB font_weight=bold color=White fontsize=7pt}
	style(column)=[background=white fontsize=7pt];
column continent  group_70, (total_deaths_per_million deaths_per_cases=moyenne);
define continent / "Continents" group style={fontsize=8pt};
define group_70 / across "Groupe de pays par continent selon la part de @ la population âgée de plus de 70 ans";
define total_deaths_per_million / sum 'Nbr de mort total @ (par million)' format=6.2;
define moyenne / mean '% de mortalité moyen des @personnes infecté du covid' format=6.2  
	style={COLOR=percentcolors. font_weight=gras.}
	style(header)={color=WHITE};
rbreak after/summarize 
	style={font_weight=BOLD fontsize=8pt};
compute after ;
Continent="World";
endcomp;
run;


ods powerpoint options(backgroundimage="&chemin/image.jpg");
ods powerpoint layout=TitleSlide;
proc odstext;
	p "Conclusions" / style=PresentationTitle[color=White];

run;

ods powerpoint close;


