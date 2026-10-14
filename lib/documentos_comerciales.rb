# El material que se le entrega a un colegio o a un aliado —el contrato,
# «Aliados» y «Qué hace hoy»—, escrito en el repo y con los números del código.
#
#     bin/rails comercial:documentos     # los tres PDF, y su copia en la carpeta madre
#
# Hasta el 13 de octubre de 2026 vivían solo en la carpeta madre, en Pages y en
# PDF, y se quedaron atrás sin que nada lo dijera: el contrato pedía elegir un
# «Plan Básico, Estándar o Premium», «Aliados» calculaba las comisiones sobre las
# bandas de 30, 60 y 90 $, y «Qué hace hoy» daba por «en construcción» funciones
# que ya estaban. Daniel: *«debemos tener una única verdad de todo»*.
#
# ⚠️ El precio y los plazos NO se escriben en las plantillas: salen de
# `Subscription`, igual que en la portada. Lo cuida `documentos_comerciales_test`,
# que cambia los precios por unos que no existen y exige que los documentos
# digan ESOS.
module DocumentosComerciales
  CARPETA   = Rails.root.join("docs/comercial")
  PUBLICADO = CARPETA.join("publicado")

  # Cada documento, y el nombre con que se deja en la carpeta madre: el MISMO
  # que tenía allá, para que reemplace al viejo en vez de sumarse a su lado.
  DOCUMENTOS = {
    "contrato"     => { titulo: "Contrato de prestación de servicios", copia: "CONTRATO DE PRESTACIÓN DE SERVICIOS.pdf" },
    "aliados"      => { titulo: "SIGA · Aliados", copia: "SIGA - Aliados.pdf", subcarpeta: "DOCs" },
    "que_hace_hoy" => { titulo: "SIGA · Qué hace hoy", copia: "SIGA - Qué hace hoy.pdf", subcarpeta: "DOCs" }
  }.freeze

  module_function

  def html(nombre)
    plantilla = ERB.new(CARPETA.join("#{nombre}.html.erb").read, trim_mode: "-")
    plantilla.result(Contexto.new(DOCUMENTOS.fetch(nombre)[:titulo]).instance_eval { binding })
  end

  def publicar!(nombre)
    datos = DOCUMENTOS.fetch(nombre)
    pdf = DocumentoImpreso.desde_html(html(nombre), PUBLICADO.join("#{nombre.tr('_', '-')}.pdf"))
    copia = DocumentoImpreso.copiar_a_la_carpeta_madre(pdf, datos[:copia], subcarpeta: datos[:subcarpeta])
    [ pdf, copia ]
  end

  # Lo que las plantillas pueden pedir. Los montos con el formato de la app:
  # «0,35», «45,00» y «126,00».
  class Contexto
    include ERB::Util

    attr_reader :titulo

    def initialize(titulo)
      @titulo = titulo
    end

    def precio = cifra(Subscription::PRECIO_POR_ALUMNO)
    def minimo = cifra(Subscription::MINIMO_MENSUAL)
    def dias_de_aviso = Subscription::DIAS_DE_AVISO
    def dias_de_gracia = Subscription.column_defaults["dias_de_gracia"]

    # Lo que paga un colegio de tantos alumnos, y la comisión de un aliado
    # sobre eso: la misma cuenta que «Suscripción».
    def mensualidad(alumnos) = Subscription.cotizar(alumnos).monto
    def comision(alumnos, porcentaje) = (mensualidad(alumnos) * porcentaje / 100).round(2)

    def cifra(monto) = helpers.cifra(monto)
    def estilo = CARPETA.join("estilo.css").read
    def hoy = I18n.l(Date.current, format: :long)

    private

    def helpers = ApplicationController.helpers
  end
end
