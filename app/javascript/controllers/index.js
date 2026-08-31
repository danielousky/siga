// Los controladores, registrados a mano.
//
// ⚠️ Acá vivía `eagerLoadControllersFrom("controllers", application)`, que con
// importmap convierte **cada controlador en su propia petición HTTP, en cada
// página** — incluidas las que no usan ninguno. Eran ocho peticiones extra que
// en la máquina de desarrollo son gratis y en un colegio de Guanare son dos
// segundos: con 500 ms de ida y vuelta, la latencia le gana a los bytes.
//
// Importarlos a mano cuesta una línea por controlador nuevo y los deja en el
// mismo archivo. Es el precio correcto.
import { application } from "controllers/application"

import AsistenciaController from "controllers/asistencia_controller"
import AutoEnvioController from "controllers/auto_envio_controller"
import BusquedaController from "controllers/busqueda_controller"
import CargaNotasController from "controllers/carga_notas_controller"
import CopiarController from "controllers/copiar_controller"
import EscalaPorNivelController from "controllers/escala_por_nivel_controller"
import FiltroLocalController from "controllers/filtro_local_controller"
import PasswordVisibilityController from "controllers/password_visibility_controller"
import PonderacionController from "controllers/ponderacion_controller"
import MenuController from "controllers/menu_controller"
import SidebarController from "controllers/sidebar_controller"
import UbicacionController from "controllers/ubicacion_controller"
import SearchFilterController from "controllers/search_filter_controller"

application.register("asistencia", AsistenciaController)
application.register("auto-envio", AutoEnvioController)
application.register("busqueda", BusquedaController)
application.register("carga-notas", CargaNotasController)
application.register("copiar", CopiarController)
application.register("escala-por-nivel", EscalaPorNivelController)
application.register("filtro-local", FiltroLocalController)
application.register("password-visibility", PasswordVisibilityController)
application.register("ponderacion", PonderacionController)
application.register("menu", MenuController)
application.register("sidebar", SidebarController)
application.register("ubicacion", UbicacionController)
application.register("search-filter", SearchFilterController)
