class LibriController < ApplicationController
  before_action :qualcuno?
  before_action :admin?, only: [:approva, :approvare]
  def new
    @libro = Libro.new
  end

  def create
    if utente_corrente.admin?
      findutente = Utente.find_by_cognome(params[:libro][:utente].downcase)
      if findutente
        utente = findutente
      else
        utente = utente_corrente
      end
    else
      utente = utente_corrente
    end
      @libro = Libro.new(parametri_creazione.merge(utente: utente, stato: 0))
    if @libro.save
      redirect_to @libro
      flash[:success] = "Grazie per aver deciso di condividere questo libro con la classe, #{utente_corrente.cognome.capitalize}"
    else
      redirect_to new_libro_path
      flash[:danger] = "#{@libro.errors.each {|errore| puts errore.to_s }}"
    end
  end

  def index
    unless loggato?
      redirect_to login_path
    end
    @ricerca = Libro.search(params[:cerca], params[:genere], params[:pagine])
      if params[:disponibili].nil?
        @pagy, @libro = pagy(@ricerca)
      elsif params[:disponibili] == '1'
        @librivalidi = []
        @ricerca.each do |libro|
          if !Prestito.where(libro: libro, stato: 1).or(Prestito.where(libro: libro, stato: 0))  .any?
            @librivalidi.push(libro)
          end
        end
        @pagy, @libro = pagy(Libro.where(id: @librivalidi.map(&:id)))
      end
  end

  def show
    @libro = Libro.find(params[:id].to_i)
  end

  def approvare
    @libri = Libro.where(stato: 0)
  end

  def approva
    @libro = Libro.find(params[:id].to_i)
    if utente_corrente.admin?
      @libro.update_attribute(:stato, 1)
      redirect_to root_path
      flash[:success] = 'Libro approvato'
    else
      redirect_to root_path
      flash[:danger] = "Non sei amministratore. Tornatene da dove sei venuto."
    end
  end

  def edit
    @libro = Libro.find(params[:id])
    unless utente_corrente.admin? || @libro.utente == utente_corrente
      redirect_to libri_path
      flash[:danger] = 'Non sei admin o il proprietario del libro. Tornatene da dove sei venuto.'
    end
    session[:libro_modifica] = @libro.id
  end

  def destroy
    @libro = Libro.find(params[:id])
    unless utente_corrente.admin? || @libro.utente == utente_corrente
      redirect_to libri_path and return
      flash[:danger] = 'Non sei admin o il proprietario del libro. Tornatene da dove sei venuto.'
    end
      if @libro.destroy
        redirect_to root_path
        flash[:success] = "Libro eliminato con successo."
      end
  end

  def update
    @libro = Libro.find(session[:libro_modifica]) || Libro.find(params[:id])
    unless utente_corrente.admin? || @libro.utente == utente_corrente
      redirect_to libri_path and return
      flash[:danger] = 'Non sei admin o il proprietario del libro. Tornatene da dove sei venuto.'
    end
      if !params[:libro][:utente].blank?
        utente = Utente.find_by_cognome(params[:libro][:utente].downcase)
      else
        utente = @libro.utente
      end
      if @libro.update_attributes(parametri_creazione.merge(utente: utente))
        redirect_to @libro
        flash[:success] = "Informazioni del libro modificate con successo."
      else
        render 'edit'
        flash[:danger] = "Errore #{@libro.errors.each { |error| puts error}}"
      end
  end

end

private
  def parametri_creazione
      params.require(:libro).permit(:titolo, :autore, :utente, :isbn, :trama, :foto, :costo, :immagine, :genere, :pagine)
  end
