import { StyleSheet, View, Text, Alert, Pressable } from 'react-native'
import React, { useRef, useState } from 'react'
import ScreenWrapper from '../components/screen_wrapper'
import Input from '../components/input'
import Button from '../components/button'
import { theme } from '../constants/theme'
import Icon from '../assets/icons'
import { StatusBar } from 'expo-status-bar'
import BackButton from '../components/BackButton'
import { useRouter } from 'expo-router'
import { hp, wp } from '../helpers/common'

const SignUp = () => {
  const router = useRouter();
  const nameRef = useRef('');
  const fatherNameRef = useRef('');
  const motherNameRef = useRef('');
  const emailRef = useRef('');
  const passwordRef = useRef('');
  const [loading, setLoading] = useState(false);

  const onSubmit = async () => {
    if (!emailRef.current || !passwordRef.current) {
      Alert.alert('Crear Cuenta', 'Por favor ingresa los datos requeridos');
      return;
    }

    let name = nameRef.current.trim();
    let fatherName = fatherNameRef.current.trim();
    let motherName = motherNameRef.current.trim();
    let email = emailRef.current.trim();
    let password = passwordRef.current.trim();

    setLoading(true);

    const {data: {session}, error} = await supabase.auth.signUp({
      email,
      password,
      data: {
        name,
        fatherName,
        motherName,
      },
    });

    setLoading(false);

    console.log('session', session);
    console.log('error', error);

    if(!error) {
      Alert.alert('Registro', error.message);
      return;
    }
  }
  return (
    <ScreenWrapper bg={'white'}>
      <StatusBar style='dark' />
      <View style={styles.container}>
        <BackButton router={router} />

        {/* welcome */}
        <View >
          <Text style={styles.welcomeText}>Vamos a,</Text>
          <Text style={styles.welcomeText}>crear tu cuenta</Text>
        </View>

        {/* form */}
        <View style={styles.form}>
          <Text style={{ fontSize: hp(1.5), color: theme.colors.text }}>
            Por favor ingresa la información requerida para crear tu cuenta
          </Text>
          <Input
            icon={<Icon name='user' size={26} strokeWidth={1.6} />}
            placeholder='Ingresa tu nombre'
            onChangeText={value => nameRef.current = value}
          />
          <Input
            icon={<Icon name='user' size={26} strokeWidth={1.6} />}
            placeholder='Ingresa tu apellido paterno'
            onChangeText={value => fatherNameRef.current = value}
          />
          <Input
            icon={<Icon name='user' size={26} strokeWidth={1.6} />}
            placeholder='Ingresa tu apellido materno'
            onChangeText={value => motherNameRef.current = value}
          />
          <Input
            icon={<Icon name='mail' size={26} strokeWidth={1.6} />}
            placeholder='Ingresa tu correo electrónico'
            onChangeText={value => emailRef.current = value}
          />
          <Input
            icon={<Icon name='lock' size={26} strokeWidth={1.6} />}
            placeholder='Ingresa tu contraseña'
            secureTextEntry
            onChangeText={value => passwordRef.current = value}
          />
          <Text style={styles.forgotPassword}>
            ¿Olvidaste tu contraseña?
          </Text>
          {/* Button */}
          <Button title={'Crear Cuenta'} buttonStyle={{ marginHorizontal: wp(3) }} loading={loading} onPress={onSubmit} />
        </View>

        {/* footer */}
        <View style={styles.footer}>
          <Pressable onPress={() => router.push('login')}>
            <Text style={styles.footerText}>
              ¿Ya tienes cuenta?
            </Text>
            <Text style={[
              styles.footerText,
              { color: theme.colors.primaryDark, fontWeight: theme.fonts.semibold }
            ]}>
              ¡Inicia sesión!
            </Text>
          </Pressable>
        </View>
      </View>
    </ScreenWrapper>
  )
}

export default SignUp

const styles = StyleSheet.create({
  container: {
    flex: 1,
    gap: 45,
    paddingHorizontal: wp(5),
  },
  welcomeText: {
    fontSize: hp(4),
    fontWeight: theme.fonts.bold,
    color: theme.colors.text,
  },
  form: {
    gap: 25
  },
  forgotPassword: {
    color: theme.colors.text,
    fontSize: hp(1.6),
    textAlign: 'right',
    fontWeight: theme.fonts.semibold,
  },
  footer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 5,
  },
  footerText: {
    textAlign: 'center',
    color: theme.colors.text,
    fontSize: hp(1.6),
  },
})