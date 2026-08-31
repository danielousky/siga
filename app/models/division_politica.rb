# Municipios y parroquias de Venezuela (MOR-159).
#
# ## Por qué existe
#
# La entidad federal ya era una lista cerrada. El municipio y la parroquia eran
# campos de texto, y eso produce «Libertador», «Mcpio. Libertador» y «LIBERTADOR»
# para el mismo lugar — en datos que salen IMPRESOS en los documentos del MPPE.
#
# Escribir a mano es el último recurso, no el primero: se elige el estado y el
# municipio se despliega solo.
#
# ## ⚠️ ESTE CATÁLOGO ESTÁ INCOMPLETO Y HAY QUE VERIFICARLO
#
# Venezuela tiene 335 municipios y ~1.150 parroquias. Lo que hay acá se escribió
# de memoria y **no se contrastó contra una fuente oficial** (INE o CNE). Puede
# tener nombres mal escritos, municipios que faltan y parroquias que no están.
#
# Por eso `OTRO` existe y no es decorativo: **cualquier lugar que no esté en la
# lista se puede escribir a mano.** Un catálogo equivocado nunca puede impedirle
# a un colegio registrarse — y ese es el modo de fallar que había que evitar,
# porque un colegio que no puede registrarse no vuelve.
#
# Antes de dar esto por bueno: bajar el catálogo del INE y reemplazar el hash.
# La estructura no cambia; los datos sí.
class DivisionPolitica
  OTRO = "__otro__".freeze

  # entidad => { municipio => [parroquias] }
  #
  # Un municipio con `[]` significa «lo tengo, pero no sus parroquias»: la
  # parroquia se escribe a mano y el municipio igual se elige de la lista.
  MUNICIPIOS = {
    "Distrito Capital" => {
      "Libertador" => [
        "Altagracia", "Antímano", "Caricuao", "Catedral", "Coche", "El Junquito",
        "El Paraíso", "El Recreo", "El Valle", "La Candelaria", "La Pastora",
        "La Vega", "Macarao", "San Agustín", "San Bernardino", "San José",
        "San Juan", "San Pedro", "Santa Rosalía", "Santa Teresa", "Sucre", "23 de Enero"
      ]
    },
    "Miranda" => {
      "Acevedo" => [], "Andrés Bello" => [], "Baruta" => [ "Baruta", "El Cafetal", "Las Minas de Baruta" ],
      "Brión" => [], "Buroz" => [], "Carrizal" => [], "Chacao" => [ "Chacao" ],
      "Cristóbal Rojas" => [], "El Hatillo" => [ "El Hatillo" ], "Guaicaipuro" => [],
      "Independencia" => [], "Lander" => [], "Los Salias" => [], "Páez" => [],
      "Paz Castillo" => [], "Pedro Gual" => [], "Plaza" => [], "Simón Bolívar" => [],
      "Sucre" => [ "Petare", "Caucagüita", "Fila de Mariches", "La Dolorita", "Leoncio Martínez" ],
      "Urdaneta" => [], "Zamora" => []
    },
    "La Guaira" => { "Vargas" => [] },
    "Carabobo" => {
      "Bejuma" => [], "Carlos Arvelo" => [], "Diego Ibarra" => [], "Guacara" => [],
      "Juan José Mora" => [], "Libertador" => [], "Los Guayos" => [], "Miranda" => [],
      "Montalbán" => [], "Naguanagua" => [], "Puerto Cabello" => [], "San Diego" => [],
      "San Joaquín" => [], "Valencia" => [ "Candelaria", "Catedral", "El Socorro", "Miguel Peña", "Rafael Urdaneta", "San Blas", "San José", "Santa Rosa" ]
    },
    "Zulia" => {
      "Almirante Padilla" => [], "Baralt" => [], "Cabimas" => [], "Catatumbo" => [],
      "Colón" => [], "Francisco Javier Pulgar" => [], "Jesús Enrique Lossada" => [],
      "Jesús María Semprún" => [], "La Cañada de Urdaneta" => [], "Lagunillas" => [],
      "Machiques de Perijá" => [], "Mara" => [], "Maracaibo" => [ "Antonio Borjas Romero", "Bolívar", "Cacique Mara", "Cecilio Acosta", "Chiquinquirá", "Coquivacoa", "Cristo de Aranza", "Francisco Eugenio Bustamante", "Idelfonso Vásquez", "Juana de Ávila", "Luis Hurtado Higuera", "Manuel Dagnino", "Olegario Villalobos", "Raúl Leoni", "Santa Lucía", "Venancio Pulgar" ],
      "Miranda" => [], "Rosario de Perijá" => [], "San Francisco" => [],
      "Santa Rita" => [], "Simón Bolívar" => [], "Sucre" => [], "Valmore Rodríguez" => []
    },
    "Lara" => {
      "Andrés Eloy Blanco" => [], "Crespo" => [], "Iribarren" => [ "Catedral", "Concepción", "El Cují", "Juan de Villegas", "Santa Rosa", "Tamaca", "Unión", "Aguedo Felipe Alvarado", "Buena Vista" ],
      "Jiménez" => [], "Morán" => [], "Palavecino" => [], "Simón Planas" => [],
      "Torres" => [], "Urdaneta" => []
    },
    "Aragua" => {
      "Bolívar" => [], "Camatagua" => [], "Francisco Linares Alcántara" => [],
      "Girardot" => [ "Las Delicias", "Choroní", "Madre María", "Pedro José Ovalles", "Joaquín Crespo", "José Casanova Godoy", "Andrés Eloy Blanco" ],
      "José Ángel Lamas" => [], "José Félix Ribas" => [], "José Rafael Revenga" => [],
      "Libertador" => [], "Mario Briceño Iragorry" => [], "Ocumare de la Costa de Oro" => [],
      "San Casimiro" => [], "San Sebastián" => [], "Santiago Mariño" => [],
      "Santos Michelena" => [], "Sucre" => [], "Tovar" => [], "Urdaneta" => [], "Zamora" => []
    },
    "Anzoátegui" => {
      "Anaco" => [], "Aragua" => [], "Diego Bautista Urbaneja" => [], "Fernando de Peñalver" => [],
      "Francisco del Carmen Carvajal" => [], "Francisco de Miranda" => [], "Guanta" => [],
      "Independencia" => [], "José Gregorio Monagas" => [], "Juan Antonio Sotillo" => [],
      "Juan Manuel Cajigal" => [], "Libertad" => [], "Manuel Ezequiel Bruzual" => [],
      "Pedro María Freites" => [], "Píritu" => [], "San José de Guanipa" => [],
      "San Juan de Capistrano" => [], "Santa Ana" => [], "Simón Bolívar" => [],
      "Simón Rodríguez" => [], "Sir Arthur McGregor" => []
    },
    "Bolívar" => {
      "Caroní" => [], "Cedeño" => [], "El Callao" => [], "Gran Sabana" => [],
      "Heres" => [], "Padre Pedro Chien" => [], "Piar" => [], "Angostura" => [],
      "Roscio" => [], "Sifontes" => [], "Sucre" => []
    },
    "Táchira" => {
      "Andrés Bello" => [], "Antonio Rómulo Costa" => [], "Ayacucho" => [], "Bolívar" => [],
      "Cárdenas" => [], "Córdoba" => [], "Fernández Feo" => [], "Francisco de Miranda" => [],
      "García de Hevia" => [], "Guásimos" => [], "Independencia" => [], "Jáuregui" => [],
      "José María Vargas" => [], "Junín" => [], "Libertad" => [], "Libertador" => [],
      "Lobatera" => [], "Michelena" => [], "Panamericano" => [], "Pedro María Ureña" => [],
      "Rafael Urdaneta" => [], "Samuel Darío Maldonado" => [], "San Cristóbal" => [ "La Concordia", "Pedro María Morantes", "San Juan Bautista", "San Sebastián", "Dr. Francisco Romero Lobo" ],
      "Seboruco" => [], "Simón Rodríguez" => [], "Sucre" => [], "Torbes" => [], "Uribante" => []
    },
    "Mérida" => {
      "Alberto Adriani" => [], "Andrés Bello" => [], "Antonio Pinto Salinas" => [],
      "Aricagua" => [], "Arzobispo Chacón" => [], "Campo Elías" => [], "Caracciolo Parra Olmedo" => [],
      "Cardenal Quintero" => [], "Guaraque" => [], "Julio César Salas" => [], "Justo Briceño" => [],
      "Libertador" => [ "Antonio Spinetti Dini", "Arias", "Caracciolo Parra Pérez", "Domingo Peña", "El Llano", "Gonzalo Picón Febres", "Jacinto Plaza", "Juan Rodríguez Suárez", "Lasso de la Vega", "Mariano Picón Salas", "Milla", "Osuna Rodríguez", "Sagrario", "El Morro", "Los Nevados" ],
      "Miranda" => [], "Obispo Ramos de Lora" => [], "Padre Noguera" => [], "Pueblo Llano" => [],
      "Rangel" => [], "Rivas Dávila" => [], "Santos Marquina" => [], "Sucre" => [],
      "Tique" => [], "Tovar" => [], "Zea" => []
    },
    "Falcón" => {
      "Acosta" => [], "Bolívar" => [], "Buchivacoa" => [], "Cacique Manaure" => [],
      "Carirubana" => [], "Colina" => [], "Dabajuro" => [], "Democracia" => [],
      "Falcón" => [], "Federación" => [], "Jacura" => [], "Los Taques" => [],
      "Mauroa" => [], "Miranda" => [], "Monseñor Iturriza" => [], "Palmasola" => [],
      "Petit" => [], "Píritu" => [], "San Francisco" => [], "Silva" => [],
      "Sucre" => [], "Tocópero" => [], "Unión" => [], "Urumaco" => [], "Zamora" => []
    },
    "Portuguesa" => {
      "Agua Blanca" => [], "Araure" => [], "Esteller" => [], "Guanare" => [],
      "Guanarito" => [], "Monseñor José Vicente de Unda" => [], "Ospino" => [],
      "Páez" => [], "Papelón" => [], "San Genaro de Boconoíto" => [],
      "San Rafael de Onoto" => [], "Santa Rosalía" => [], "Sucre" => [], "Turén" => []
    },
    "Barinas" => {
      "Alberto Arvelo Torrealba" => [], "Andrés Eloy Blanco" => [], "Antonio José de Sucre" => [],
      "Arismendi" => [], "Barinas" => [], "Bolívar" => [], "Cruz Paredes" => [],
      "Ezequiel Zamora" => [], "Obispos" => [], "Pedraza" => [], "Rojas" => [], "Sosa" => []
    },
    "Guárico" => {
      "Camaguán" => [], "Chaguaramas" => [], "El Socorro" => [], "Francisco de Miranda" => [],
      "José Félix Ribas" => [], "José Tadeo Monagas" => [], "Juan Germán Roscio" => [],
      "Julián Mellado" => [], "Las Mercedes" => [], "Leonardo Infante" => [],
      "Ortiz" => [], "San Gerónimo de Guayabal" => [], "San José de Guaribe" => [],
      "Santa María de Ipire" => [], "Zaraza" => []
    },
    "Sucre" => {
      "Andrés Eloy Blanco" => [], "Andrés Mata" => [], "Arismendi" => [], "Benítez" => [],
      "Bermúdez" => [], "Bolívar" => [], "Cajigal" => [], "Cruz Salmerón Acosta" => [],
      "Libertador" => [], "Mariño" => [], "Mejía" => [], "Montes" => [],
      "Ribero" => [], "Sucre" => [], "Valdez" => []
    },
    "Monagas" => {
      "Acosta" => [], "Aguasay" => [], "Bolívar" => [], "Caripe" => [], "Cedeño" => [],
      "Ezequiel Zamora" => [], "Libertador" => [], "Maturín" => [], "Piar" => [],
      "Punceres" => [], "Santa Bárbara" => [], "Sotillo" => [], "Uracoa" => []
    },
    "Trujillo" => {
      "Andrés Bello" => [], "Boconó" => [], "Bolívar" => [], "Candelaria" => [],
      "Carache" => [], "Escuque" => [], "José Felipe Márquez Cañizales" => [],
      "Juan Vicente Campo Elías" => [], "La Ceiba" => [], "Miranda" => [],
      "Monte Carmelo" => [], "Motatán" => [], "Pampán" => [], "Pampanito" => [],
      "Rafael Rangel" => [], "San Rafael de Carvajal" => [], "Sucre" => [],
      "Trujillo" => [], "Urdaneta" => [], "Valera" => []
    },
    "Yaracuy" => {
      "Arístides Bastidas" => [], "Bolívar" => [], "Bruzual" => [], "Cocorote" => [],
      "Independencia" => [], "José Antonio Páez" => [], "La Trinidad" => [],
      "Manuel Monge" => [], "Nirgua" => [], "Peña" => [], "San Felipe" => [],
      "Sucre" => [], "Urachiche" => [], "Veroes" => []
    },
    "Cojedes" => {
      "Anzoátegui" => [], "Falcón" => [], "Girardot" => [], "Lima Blanco" => [],
      "Pao de San Juan Bautista" => [], "Ricaurte" => [], "Rómulo Gallegos" => [],
      "San Carlos" => [], "Tinaco" => []
    },
    "Nueva Esparta" => {
      "Antolín del Campo" => [], "Arismendi" => [], "Díaz" => [], "García" => [],
      "Gómez" => [], "Maneiro" => [], "Marcano" => [], "Mariño" => [],
      "Península de Macanao" => [], "Tubores" => [], "Villalba" => []
    },
    "Apure" => {
      "Achaguas" => [], "Biruaca" => [], "Muñoz" => [], "Páez" => [],
      "Pedro Camejo" => [], "Rómulo Gallegos" => [], "San Fernando" => []
    },
    "Amazonas" => {
      "Alto Orinoco" => [], "Atabapo" => [], "Atures" => [], "Autana" => [],
      "Manapiare" => [], "Maroa" => [], "Río Negro" => []
    },
    "Delta Amacuro" => {
      "Antonio Díaz" => [], "Casacoima" => [], "Pedernales" => [], "Tucupita" => []
    },
    "Dependencias Federales" => {}
  }.freeze

  class << self
    def municipios_de(entidad) = MUNICIPIOS.fetch(entidad.to_s, {}).keys

    def parroquias_de(entidad, municipio)
      MUNICIPIOS.dig(entidad.to_s, municipio.to_s) || []
    end

    # Lo que come el JavaScript del desplegable en cascada: un solo objeto, sin
    # una petición por cada cambio de estado. Son ~20 KB — menos que un icono.
    def como_json_para_el_navegador = MUNICIPIOS.to_json

    # ⚠️ Nunca se rechaza un lugar que no esté en el catálogo. Ver la nota de
    # arriba: el catálogo está incompleto y no puede impedir un registro.
    def conocido?(entidad, municipio) = municipios_de(entidad).include?(municipio.to_s)
  end
end
