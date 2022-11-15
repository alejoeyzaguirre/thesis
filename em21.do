* Tesis Magíster Economía
* Pontificia Universidad Católica de Chile
* Alejo Eyzaguirre

clear all 

cd "/Users/alejoeyzaguirre/Desktop/Tesis/Datos"

global raw "/Users/alejoeyzaguirre/Desktop/Tesis/Datos" 
global output "/Users/alejoeyzaguirre/Desktop/Tesis/Datos/Urgencias" 


********************************************************************************

******************** Preparación Treatment x Comuna ****************************

********************************************************************************


* Treatment por comunas:
use "$raw/Internet/casen17", clear

* Nos quedamos solo con las vars relevantes:
keep comuna region expc r21d r21b

* Dado que CASEN solo tiene info representativa para comunas en RM:
labellist region
keep if region == 13

* Expandimos:
expand expc

* Vemos el número total de "personas" (entrevistadas) por comuna:
gen id = _n
egen num = count(id), by(comuna)

* Que porcentaje de los encuestados usa internet para comunicarse por RRSS:
replace r21d = 0 if r21d == 2 | r21d == 9 | r21d == .

* Colapsamos por comuna: ? Qué hago con los missing values?
collapse (sum) r21d, by(comuna num)

* Generamos nuestro treatment:
gen treatment = r21d / num

* Generamos variable string de comuna:
decode comuna, gen(nombrecomuna) 

* Arreglamos los <?>
replace nombrecomuna = "Alhué" if comuna == 13502
replace nombrecomuna = "Conchalí" if comuna == 13104
replace nombrecomuna = "Curacaví" if comuna == 13503
replace nombrecomuna = "Estación Central" if comuna == 13106
replace nombrecomuna = "Maipú" if comuna == 13119
replace nombrecomuna = "María Pinto" if comuna == 13504
replace nombrecomuna = "Peñaflor" if comuna == 13605
replace nombrecomuna = "Peñalolén" if comuna == 13122
replace nombrecomuna = "San Joaquín" if comuna == 13129
replace nombrecomuna = "San José de Maipo" if comuna == 13203
replace nombrecomuna = "San Ramón" if comuna == 13131
replace nombrecomuna = "Ñuñoa" if comuna == 13120

* Guardamos:
save "$output/intmun", replace


********************************************************************************

************************** Usando Datos EM 2021 ********************************

********************************************************************************


* Importe Base que ya fue pre-procesada en Python (ver thesis.ipynb)
use "$output/emergencies", clear

* Me quedo solo con causas relacionadas a salud mental: : ()
tab glosacausa
keep if idcausa > 34 & idcausa <43

* Nos quedamos solo con obs. de la RM:
gen region = round(códigocomuna / 1000)
keep if region == 13

/* Figuras: 
collapse (sum) total, by(dia mes)

gen diasemana = 0
replace diasemana = mod(dia+4,7) if mes == 1
replace diasemana = mod(dia+0,7) if mes == 2
replace diasemana = mod(dia+0,7) if mes == 3
replace diasemana = mod(dia+3,7) if mes == 4
replace diasemana = mod(dia+5,7) if mes == 5
replace diasemana = mod(dia+1,7) if mes == 6
replace diasemana = mod(dia+3,7) if mes == 7
replace diasemana = mod(dia+6,7) if mes == 8
replace diasemana = mod(dia+2,7) if mes == 9
replace diasemana = mod(dia+4,7) if mes == 10
replace diasemana = mod(dia+0,7) if mes == 11
replace diasemana = mod(dia+2,7) if mes == 12
replace diasemana = 7 if diasemana == 0

gen during = 99
replace during = 0 if (dia > 12 & mes == 9) | (dia < 4 & mes == 10)
replace during = 1 if dia == 4 & mes == 10
replace during = 2 if (dia > 4 & dia < 26 & mes == 10) 
drop if during == 99

collapse (mean) total, by(diasemana during)

drop if during == 2
replace during = -1 if during == 1
sort diasemana during
gen categ = _n

replace total = total -1200

set scheme s1color
statplot total , over(categ) vertical legend(off)

*/

* Sacamos la suma de todas los ingresos por Salud Mental entre todas las comunas
* de cada día:
collapse (sum) total, by(dia mes nombrecomuna códigocomuna)
sort nombrecomuna mes dia

* Juntamos con base de Treatment a partir de CASEN 2017.
merge m:1 nombrecomuna using "$output/intmun", nogen 

* Generamos variable treat*during
gen treatpost = 0
replace treatpost = treatment if dia == 4 & mes == 10




* Ahora limpiamos de estacionalidad la variable total:
gen diasemana = 0
replace diasemana = mod(dia+4,7) if mes == 1
replace diasemana = mod(dia+0,7) if mes == 2
replace diasemana = mod(dia+0,7) if mes == 3
replace diasemana = mod(dia+3,7) if mes == 4
replace diasemana = mod(dia+5,7) if mes == 5
replace diasemana = mod(dia+1,7) if mes == 6
replace diasemana = mod(dia+3,7) if mes == 7
replace diasemana = mod(dia+6,7) if mes == 8
replace diasemana = mod(dia+2,7) if mes == 9
replace diasemana = mod(dia+4,7) if mes == 10
replace diasemana = mod(dia+0,7) if mes == 11
replace diasemana = mod(dia+2,7) if mes == 12
replace diasemana = 7 if diasemana == 0

bys nombrecomuna: gen num_fecha = _n
tostring diasemana, gen(st_diasemana)
tostring mes, gen(st_mes)

gen st_weekday_x_comuna = nombrecomuna + " " + st_diasemana
gen st_mes_x_comuna = nombrecomuna + " " + st_mes

encode st_weekday_x_comuna, gen(weekday_x_comuna)
encode st_mes_x_comuna, gen(mes_x_comuna)


reg total i.weekday_x_comuna i.mes_x_comuna
predict dtotal, res


********************************************************************************

************************* Diferencias-en-Diferencias ***************************

********************************************************************************

preserve
drop if dia > 4 & mes == 10 | mes > 10

* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe total treatpost, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe total treatpost, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe total treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)



* MARGEN EXTENSIVO
gen ex_total = (total > 0)

* Efecto Fijo TWFE
reghdfe ex_total treatpost, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_total treatpost, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_total treatpost, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)
restore


********************************************************************************

************************* Placebo Tests ****************************************

********************************************************************************


preserve
drop if dia > 28 & mes == 9 | mes > 9
gen treatpost2 = 0
replace treatpost2 = treatment if dia == 28 & mes == 9
* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe total treatpost2, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe total treatpost2, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe total treatpost2, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)



* MARGEN EXTENSIVO
gen ex_total = (total > 0)

* Efecto Fijo TWFE
reghdfe ex_total treatpost2, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_total treatpost2, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_total treatpost2, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)
restore


preserve
drop if dia > 11 & mes == 10 | mes > 10
gen treatpost3 = 0
replace treatpost3 = treatment if dia == 11 & mes == 10
* MARGEN INTENSIVO

* Efecto Fijo TWFE
reghdfe total treatpost3, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe total treatpost3, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe total treatpost3, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)



* MARGEN EXTENSIVO
gen ex_total = (total > 0)

* Efecto Fijo TWFE
reghdfe ex_total treatpost3, abs(nombrecomuna num_fecha) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna
reghdfe ex_total treatpost3, abs(nombrecomuna num_fecha mes_x_comuna) vce(cl nombrecomuna)

* Efecto Fijo TWFE + Mes x Comuna + DayOfTheWeek x Comuna
reghdfe ex_total treatpost3, abs(nombrecomuna num_fecha mes_x_comuna weekday_x_comuna) vce(cl nombrecomuna)
restore




preserve
sum treatment, d
gen status = (treatment >= 0.602) // High penetration above median.
sum total if status == 0
gen av_out0 = r(mean)
sum total if status == 1
gen av_out1 = r(mean)
collapse (mean) total av_out0 av_out1, by(dia mes status)
sort status mes dia
* Only compare during outage observations:
keep if (dia == 4 & mes == 10)
collapse (mean) total av_out0 av_out1, by(status)
gen rel_out = 0
replace rel_out = total / av_out0 - 1 if status == 0
replace rel_out = total / av_out1 - 1 if status == 1
statplot rel_out , over(status) vertical legend(off)
restore


