# El contrato, «Aliados» y «Qué hace hoy», impresos desde el repo. Ver
# `lib/documentos_comerciales.rb`.
namespace :comercial do
  desc "Imprime el contrato, «Aliados» y «Qué hace hoy» a PDF, y los copia a la carpeta madre"
  task documentos: :environment do
    DocumentosComerciales::DOCUMENTOS.each_key do |nombre|
      pdf, copia = DocumentosComerciales.publicar!(nombre)
      puts "✓ #{pdf.relative_path_from(Rails.root)}#{" → #{copia}" if copia}"
    end
  end
end
