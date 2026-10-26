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

import AccionDelFormularioController from "controllers/accion_del_formulario_controller"
application.register("accion-del-formulario", AccionDelFormularioController)

import CorreoLibreController from "controllers/correo_libre_controller"
application.register("correo-libre", CorreoLibreController)

import CampoQueCreceController from "controllers/campo_que_crece_controller"
application.register("campo-que-crece", CampoQueCreceController)

import PesoDeslizanteController from "controllers/peso_deslizante_controller"
application.register("peso-deslizante", PesoDeslizanteController)

import SeDesvaneceController from "controllers/se_desvanece_controller"
application.register("se-desvanece", SeDesvaneceController)

import MedioDePagoController from "controllers/medio_de_pago_controller"
application.register("medio-de-pago", MedioDePagoController)

import AsistenciaController from "controllers/asistencia_controller"
import AreaController from "controllers/area_controller"
import AutoEnvioController from "controllers/auto_envio_controller"
import CampoFiltradoController from "controllers/campo_filtrado_controller"
import CampoTelefonoController from "controllers/campo_telefono_controller"
import BusquedaController from "controllers/busqueda_controller"
import ContextoController from "controllers/contexto_controller"
import CopiarController from "controllers/copiar_controller"
import EscalaPorNivelController from "controllers/escala_por_nivel_controller"
import FiltroLocalController from "controllers/filtro_local_controller"
import PasswordVisibilityController from "controllers/password_visibility_controller"
import PanelesController from "controllers/paneles_controller"
import PonderacionController from "controllers/ponderacion_controller"
import RepartoController from "controllers/reparto_controller"
import MenuFlotanteController from "controllers/menu_flotante_controller"
import EdicionEnLineaController from "controllers/edicion_en_linea_controller"
import EnSuSitioController from "controllers/en_su_sitio_controller"
import FotoDePerfilController from "controllers/foto_de_perfil_controller"
import CatalogoDePlantelesController from "controllers/catalogo_de_planteles_controller"
import IdentificadorController from "controllers/identificador_controller"
import IdentificadoresUsadosController from "controllers/identificadores_usados_controller"
import PasosController from "controllers/pasos_controller"
import PlanillaController from "controllers/planilla_controller"
import CalendarioEscolarController from "controllers/calendario_escolar_controller"
import QueEvaluaController from "controllers/que_evalua_controller"
import MenuController from "controllers/menu_controller"
import SidebarController from "controllers/sidebar_controller"
import UbicacionController from "controllers/ubicacion_controller"
import SearchFilterController from "controllers/search_filter_controller"

application.register("asistencia", AsistenciaController)
application.register("area", AreaController)
application.register("auto-envio", AutoEnvioController)
application.register("campo-filtrado", CampoFiltradoController)
application.register("campo-telefono", CampoTelefonoController)
application.register("busqueda", BusquedaController)
application.register("contexto", ContextoController)
application.register("copiar", CopiarController)
application.register("escala-por-nivel", EscalaPorNivelController)
application.register("filtro-local", FiltroLocalController)
application.register("password-visibility", PasswordVisibilityController)
application.register("paneles", PanelesController)
application.register("ponderacion", PonderacionController)
application.register("reparto", RepartoController)
application.register("menu-flotante", MenuFlotanteController)
application.register("edicion-en-linea", EdicionEnLineaController)
application.register("en-su-sitio", EnSuSitioController)
application.register("foto-de-perfil", FotoDePerfilController)
application.register("catalogo-de-planteles", CatalogoDePlantelesController)
application.register("identificador", IdentificadorController)
application.register("identificadores-usados", IdentificadoresUsadosController)
application.register("pasos", PasosController)
application.register("planilla", PlanillaController)
application.register("calendario-escolar", CalendarioEscolarController)
application.register("que-evalua", QueEvaluaController)
application.register("menu", MenuController)
application.register("sidebar", SidebarController)
application.register("ubicacion", UbicacionController)
application.register("search-filter", SearchFilterController)
