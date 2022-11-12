* Tesis Magíster Economía
* Pontificia Universidad Católica de Chile
* Alejo Eyzaguirre

clear all 

cd "/Users/alejoeyzaguirre/Desktop/Tesis/Datos"

global raw "/Users/alejoeyzaguirre/Desktop/Tesis/Datos" 
global output "/Users/alejoeyzaguirre/Desktop/Tesis/Datos/Urgencias" 


********************************************************************************

**************************** Usando Datos 2021 *********************************

********************************************************************************


* Treatment por comunas:
use "$raw/Internet/casen17", clear

* Nos quedamos solo con las vars relevantes:
keep comuna  region expc r21d r21b


* Expandimos:
expand expc

* Vemos el número total de "personas" (entrevistadas) por comuna:
gen id = _n
egen num = count(id), by(comuna)

* Que porcentaje de los encuestados usa internet para comunicarse por RRSS:


* Colapsamos por comuna: ? Qué hago con los missing values?
collapse (count) r21d r21b 

*/

* Importe Base que ya fue pre-procesada en Python (ver thesis.ipynb)
use "$output/emergencies", clear

* Me quedo solo con causas relacionadas a salud mental: : ()
tab glosacausa
keep if idcausa > 34 & idcausa <43



* Sacamos la suma de todas los ingresos por Salud Mental entre todas las comunas
* de cada día:
collapse (sum) total, by(dia mes)
sort mes dia

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


