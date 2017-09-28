require 'rubystats'
require 'byebug'

class Pizzeria
  def initialize(n_pi:, n_em:, repartidores:, cocineros:)
    @n_pi = n_pi
    @n_em = n_em
    @repartidores = repartidores
    @cocineros = cocineros

    @tiempo_proximo_pedido = 720
    @tiempo = 0
    @tiempo_final = 100_000_000
    @dia_actual = 0
    @dias_transcurridos = 0
    @clientes_del_local = 0
    @sumatoria_tiempo_espera_clientes_local = 0
    @clientes_delivery = 0
    @sumatoria_tiempo_espera_clientes_delivery = 0

    # Cocineros
    @tiempo_comprometido_cocineros = Array.new(cocineros, 0)
    @sumatoria_tiempo_ocioso_cocineros = Array.new(cocineros, 0)

    # HORNOS
    @tiempo_comprometido_horno_pizzas = Array.new(n_pi, 0)
    @tiempo_comprometido_horno_empanadas = Array.new(n_em, 0)

    # Repartidores
    @tiempo_comprometido_repartidores = Array.new(repartidores, 0)
    @sumatoria_tiempo_ocioso_repartidores = Array.new(repartidores, 0)

    @normal_pedido_semana_tarde = Rubystats::NormalDistribution.new(9.6, 2.8)
    @normal_pedido_semana_noche = Rubystats::NormalDistribution.new(9.3, 2.8)
    @normal_pedido_finde_tarde = Rubystats::NormalDistribution.new(6.2, 1.5)

    @normal_pizzas_semana_tarde = Rubystats::NormalDistribution.new(1.12, 0.23)
    @normal_pizzas_finde_tarde = Rubystats::NormalDistribution.new(1.21, 0.44)
    @normal_pizzas_semana_noche = Rubystats::NormalDistribution.new(1.31, 0.62)

    @normal_empanadas_semana_tarde = Rubystats::NormalDistribution.new(3.38, 1.26)
    @normal_empanadas_finde_tarde = Rubystats::NormalDistribution.new(3.12, 0.85)
    @normal_empanadas_semana_noche = Rubystats::NormalDistribution.new(3.08, 1.23)

    @normal_tiempo_de_viaje = Rubystats::NormalDistribution.new(12, 6)

    @tiempo_total_real = 0
    @asdasd = 0
  end

  def simular
    loop do
      @tiempo = @tiempo_proximo_pedido

      @dia_actual = @dias_transcurridos % 7
      @turno = calcular_turno

      @tiempo_proximo_pedido = intervalo_entre_pedidos.abs + @tiempo

      pizzas_pedidas = cantidad_pizzas.abs.round
      empanadas_pedidas = cantidad_empanadas.abs.round

      if pizzas_pedidas.zero? && empanadas_pedidas.zero?
        @asdasd += 1
        resetear if fin_del_turno?
        break if @tiempo > @tiempo_final
        next
      end

      minimo_cocinero = @tiempo_comprometido_cocineros.index(@tiempo_comprometido_cocineros.min)

      if @tiempo_comprometido_cocineros[minimo_cocinero] <= @tiempo
        @sumatoria_tiempo_ocioso_cocineros[minimo_cocinero] += @tiempo - @tiempo_comprometido_cocineros[minimo_cocinero]
        @comienzo_de_preparacion = @tiempo
      else
        @comienzo_de_preparacion = @tiempo_comprometido_cocineros[minimo_cocinero]
      end

      tiempo_salida_pizzas = cocinar(pizzas_pedidas, :pizza)
      tiempo_salida_empanadas = cocinar(empanadas_pedidas, :empanada)

      tiempo_final_preparacion = [tiempo_salida_empanadas, tiempo_salida_pizzas].max

      @tiempo_comprometido_cocineros[minimo_cocinero] = @comienzo_de_preparacion

      cliente = calcular_tipo_de_cliente

      if cliente == :local
        @clientes_del_local += 1
        @sumatoria_tiempo_espera_clientes_local += tiempo_final_preparacion - @tiempo
      else
        @clientes_delivery += 1
        tiempo_delivery = calcular_tiempo_delivery
        minimo_repartidor = @tiempo_comprometido_repartidores.index(@tiempo_comprometido_repartidores.min)

        if @tiempo_comprometido_repartidores[minimo_repartidor] <= tiempo_final_preparacion
          @sumatoria_tiempo_ocioso_repartidores[minimo_repartidor] += tiempo_final_preparacion - @tiempo_comprometido_repartidores[minimo_repartidor]
          @tiempo_comprometido_repartidores[minimo_repartidor] = tiempo_final_preparacion + tiempo_delivery * 2
        else
          tiempo_final_preparacion = @tiempo_comprometido_repartidores[minimo_repartidor]
          @tiempo_comprometido_repartidores[minimo_repartidor] += tiempo_delivery * 2
        end

        tiempo_final_preparacion += tiempo_delivery
        @sumatoria_tiempo_espera_clientes_delivery += tiempo_final_preparacion - @tiempo
      end

      resetear if fin_del_turno?
      break if @tiempo > @tiempo_final
    end
    imprimir_resultados
  end

  private

  def calcular_turno
    minuto = @tiempo - (@dias_transcurridos * 1440); # 1440 es la cantidad de minutos en un dia
    return :tarde if minuto >= 720 && minuto <= 900
    return :noche if minuto >= 1170 && minuto <= 1380
    raise StandardError, 'TURNO NO SOPORTADO'
  end

  def intervalo_entre_pedidos
    if @turno == :tarde
      if @dia_actual <= 3
        @normal_pedido_semana_tarde.rng
      else
        @normal_pedido_finde_tarde.rng
      end
    else
      if @dia_actual <= 3
        @normal_pedido_semana_noche.rng
      else
        9.5842 * (((rand ** (-1 / 0.20855)) - 1) ** (-1 / 8.0592))
      end
    end
  end

  def cantidad_pizzas
    if @turno == :tarde
      if @dia_actual <= 3
        @normal_pizzas_semana_tarde.rng
      else
        @normal_pizzas_finde_tarde.rng
      end
    else
      if @dia_actual <= 3
        @normal_pizzas_semana_noche.rng
      else
        2.4829 * (((rand ** (-1 / 0.19573)) - 1) ** (-1 / 7.1337))
      end
    end
  end

  def cantidad_empanadas
    if @turno == :tarde
      if @dia_actual <= 3
        @normal_empanadas_semana_tarde.rng
      else
        @normal_empanadas_finde_tarde.rng
      end
    else
      if @dia_actual <= 3
        @normal_empanadas_semana_noche.rng
      else
        6.5392 * (((rand ** (-1 / 0.19929)) - 1) ** (-1 / 7.745))
      end
    end
  end

  def cocinar(cantidad, tipo)
    if cantidad.zero?
      if tipo == :pizza
        return @tiempo_comprometido_horno_pizzas[0]
      else
        return @tiempo_comprometido_horno_empanadas[0]
      end
    end

    if tipo == :pizza
      tiempo_coccion = 9
      tiempo_preparacion = 7
    else
      tiempo_coccion = 7
      tiempo_preparacion = 0.15
    end

    ultimo_tiempo = nil

    cantidad.times do
      @comienzo_de_preparacion += tiempo_preparacion
      if tipo == :pizza
        tiempo_comprometido_horno = @tiempo_comprometido_horno_pizzas
      else
        tiempo_comprometido_horno = @tiempo_comprometido_horno_empanadas
      end

      minimo_horno = tiempo_comprometido_horno.index(tiempo_comprometido_horno.min)

      if tiempo_comprometido_horno[minimo_horno] <= @comienzo_de_preparacion
        tiempo_comprometido_horno[minimo_horno] = @comienzo_de_preparacion + tiempo_coccion
      else
        tiempo_comprometido_horno[minimo_horno] += tiempo_coccion
      end

      ultimo_tiempo = tiempo_comprometido_horno[minimo_horno]
    end

    ultimo_tiempo
  end

  def calcular_tipo_de_cliente
    random = rand
    if @dia_actual <= 3
      if @turno == :tarde
        return :local if random <= 0.8
        :delivery
      else
        return :local if random <= 0.4
        :delivery
      end
    else
      if @turno == :tarde
        return :local if random <= 0.8
        :delivery
      else
        return :local if random <= 0.4
        :delivery
      end
    end
  end

  def calcular_tiempo_delivery
    @normal_tiempo_de_viaje.rng
  end

  def fin_del_turno?
    t = @tiempo_proximo_pedido - (1440 * @dias_transcurridos)
    if @turno == :tarde
      t > 900
    elsif t > 1380
      @dias_transcurridos += 1
      return true
    else
      false
    end
  end

  def resetear
    if @turno == :tarde
      @tiempo_total_real += 900 - 720
      @tiempo_proximo_pedido = 1170 + 1440 * @dias_transcurridos
      @tiempo_comprometido_cocineros = Array.new(@tiempo_comprometido_cocineros.size, 0)
      @tiempo_comprometido_repartidores = Array.new(@tiempo_comprometido_repartidores.size, 0)
      @tiempo_comprometido_horno_pizzas = Array.new(@tiempo_comprometido_horno_pizzas.size, 0)
      @tiempo_comprometido_horno_empanadas = Array.new(@tiempo_comprometido_horno_empanadas.size, 0)
    else
      @tiempo_total_real += 1380 - 1170
      @tiempo_proximo_pedido = 720 + 1440 * @dias_transcurridos
      @tiempo_comprometido_cocineros = Array.new(@tiempo_comprometido_cocineros.size, 0)
      @tiempo_comprometido_repartidores = Array.new(@tiempo_comprometido_repartidores.size, 0)
      @tiempo_comprometido_horno_pizzas = Array.new(@tiempo_comprometido_horno_pizzas.size, 0)
      @tiempo_comprometido_horno_empanadas = Array.new(@tiempo_comprometido_horno_empanadas.size, 0)
    end
  end

  def imprimir_resultados
    total_tiempo_ocioso_cocineros = @sumatoria_tiempo_ocioso_cocineros.inject(:+)
    total_tiempo_ocioso_repartidores = @sumatoria_tiempo_ocioso_repartidores.inject(:+)

    printf("Suma de espera en local: #{@sumatoria_tiempo_espera_clientes_local} minutos \n")
    printf("Suma de espera en casa: #{@sumatoria_tiempo_espera_clientes_delivery} minutos \n")
    printf("Suma de pedidos en local: #{@clientes_del_local} \n")
    printf("Suma de pedidos en casa: #{@clientes_delivery} \n")
    printf("Suma de tiempo ocioso de cocineros: #{total_tiempo_ocioso_cocineros} minutos \n")
    printf("Suma de tiempo ocioso de repartidores: #{total_tiempo_ocioso_repartidores} minutos \n")
    printf("Tiempo total real #{@tiempo_total_real} \n")

    promedio_espera_local = @sumatoria_tiempo_espera_clientes_local.to_f / @clientes_del_local.to_f
    promedio_espera_delivery = @sumatoria_tiempo_espera_clientes_delivery.to_f / @clientes_delivery.to_f
    promedio_tiempo_ocioso_cocineros = total_tiempo_ocioso_cocineros.to_f / (@cocineros.to_f * @tiempo_total_real)
    promedio_tiempo_ocioso_repartidores = total_tiempo_ocioso_cocineros.to_f / (@repartidores.to_f * @tiempo_total_real)

    printf("Porcentaje de espera en local: #{promedio_espera_local} \n")
    printf("Porcentaje de espera en casa: #{promedio_espera_delivery} \n")
    printf("Porcentaje de tiempo ocioso de cocineros: #{promedio_tiempo_ocioso_cocineros} \n")
    printf("Porcentaje de tiempo ocioso de deliverys: #{promedio_tiempo_ocioso_repartidores} \n")
  end
end

Pizzeria.new(cocineros: 2, repartidores: 4, n_em: 96, n_pi: 8).simular
