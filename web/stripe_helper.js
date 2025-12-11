// Helper para Stripe en Flutter Web
// Este archivo proporciona funciones que usan Stripe.js directamente
// Nota: Stripe.js debe estar cargado antes de usar estas funciones

window.stripeHelper = {
  // Instancia de Stripe (se inicializa cuando se carga)
  stripe: null,
  
  // Inicializar Stripe con la clave pública
  initialize: function(publishableKey) {
    try {
      if (!publishableKey || publishableKey.length < 20) {
        throw new Error('Stripe publishable key inválida o faltante');
      }
      
      // Verificar que Stripe.js esté cargado
      if (typeof Stripe === 'undefined') {
        throw new Error('Stripe.js no está cargado. Asegúrate de incluir el script de Stripe.js en index.html');
      }
      
      // Inicializar Stripe
      this.stripe = Stripe(publishableKey);
      console.log('[stripeHelper] ✅ Stripe inicializado con publishable key');
      return true;
    } catch (error) {
      console.error('[stripeHelper] ❌ Error inicializando Stripe:', error);
      throw error;
    }
  },
  
  // Crear Payment Method con datos de tarjeta
  createPaymentMethod: async function(cardData) {
    try {
      if (!this.stripe) {
        throw new Error('Stripe no está inicializado. Llama a initialize() primero.');
      }
      
      console.log('[stripeHelper] 💳 Creando Payment Method...');
      
      // Limpiar número de tarjeta (remover espacios)
      const cleanNumber = cardData.number.replace(/\s/g, '');
      
      // Crear Payment Method usando Stripe.js
      const { paymentMethod, error } = await this.stripe.createPaymentMethod({
        type: 'card',
        card: {
          number: cleanNumber,
          exp_month: parseInt(cardData.expMonth),
          exp_year: parseInt(cardData.expYear),
          cvc: cardData.cvc,
        },
        billing_details: cardData.name ? {
          name: cardData.name,
        } : undefined,
      });
      
      if (error) {
        console.error('[stripeHelper] ❌ Error creando Payment Method:', error);
        throw new Error(error.message || 'Error creando método de pago');
      }
      
      if (!paymentMethod) {
        throw new Error('No se pudo crear el Payment Method');
      }
      
      console.log('[stripeHelper] ✅ Payment Method creado:', paymentMethod.id);
      
      return {
        id: paymentMethod.id,
        type: paymentMethod.type,
        card: paymentMethod.card ? {
          brand: paymentMethod.card.brand,
          last4: paymentMethod.card.last4,
          expMonth: paymentMethod.card.exp_month,
          expYear: paymentMethod.card.exp_year,
        } : null,
      };
    } catch (error) {
      console.error('[stripeHelper] ❌ Excepción creando Payment Method:', error);
      throw error;
    }
  },
  
  // Confirmar Payment Intent con Payment Method
  confirmPayment: async function(clientSecret, paymentMethodId) {
    try {
      if (!this.stripe) {
        throw new Error('Stripe no está inicializado. Llama a initialize() primero.');
      }
      
      if (!clientSecret || !clientSecret.startsWith('pi_')) {
        throw new Error('Client secret inválido');
      }
      
      if (!paymentMethodId || !paymentMethodId.startsWith('pm_')) {
        throw new Error('Payment Method ID inválido');
      }
      
      console.log('[stripeHelper] 💳 Confirmando Payment Intent...');
      console.log('[stripeHelper] Client Secret:', clientSecret.substring(0, 20) + '...');
      console.log('[stripeHelper] Payment Method ID:', paymentMethodId);
      
      // Confirmar Payment Intent usando Stripe.js
      // Esto maneja automáticamente 3D Secure si es requerido
      const { paymentIntent, error } = await this.stripe.confirmCardPayment(clientSecret, {
        payment_method: paymentMethodId,
      });
      
      if (error) {
        console.error('[stripeHelper] ❌ Error confirmando Payment Intent:', error);
        
        // Si el error es de autenticación (3D Secure), retornar información específica
        if (error.type === 'card_error' || error.type === 'validation_error') {
          throw {
            code: error.code || 'card_error',
            message: error.message || 'Error procesando el pago',
            type: error.type,
          };
        }
        
        throw new Error(error.message || 'Error confirmando el pago');
      }
      
      if (!paymentIntent) {
        throw new Error('No se pudo obtener el Payment Intent');
      }
      
      console.log('[stripeHelper] ✅ Payment Intent confirmado');
      console.log('[stripeHelper] Estado:', paymentIntent.status);
      
      return {
        id: paymentIntent.id,
        status: paymentIntent.status,
        clientSecret: paymentIntent.client_secret,
      };
    } catch (error) {
      console.error('[stripeHelper] ❌ Excepción confirmando Payment Intent:', error);
      
      // Si el error tiene código y mensaje (de Stripe), retornarlo
      if (error.code && error.message) {
        throw {
          code: error.code,
          message: error.message,
          type: error.type || 'card_error',
        };
      }
      
      throw error;
    }
  },
  
  // Verificar si Stripe está inicializado
  isInitialized: function() {
    return this.stripe !== null;
  },
};

// Función global para inicializar Stripe (compatibilidad)
window.stripeInitialize = function(publishableKey) {
  return window.stripeHelper.initialize(publishableKey);
};

// Función global para crear Payment Method (compatibilidad)
window.stripeCreatePaymentMethod = async function(cardData) {
  return await window.stripeHelper.createPaymentMethod(cardData);
};

// Función global para confirmar Payment Intent (compatibilidad)
window.stripeConfirmPayment = async function(clientSecret, paymentMethodId) {
  return await window.stripeHelper.confirmPayment(clientSecret, paymentMethodId);
};

