module.exports = (grunt) ->
  'use strict'
  grunt.loadNpmTasks('grunt-contrib-copy')
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-ts')
  grunt.loadNpmTasks('grunt-tslint')
  grunt.loadNpmTasks('dts-generator')

  config =
    ts:
      build:
        tsconfig: 'tsconfig.json'

    tslint:
      options:
        configuration: grunt.file.readJSON("tslint.json")
      files:
        src: [ 'src/**/*.ts' ]

    dtsGenerator:
      options:
        name: 'zk-beacon'
        baseDir: 'src/'
        out: 'build/zk-beacon.d.ts'
        main: 'zk-beacon/index'
      default:
        src: [ 'src/**/*.ts' ]

    watch:
      typescripts:
        files: 'src/**/*.ts'
        tasks: [ 'watch-compile' ]
        options:
          livereload: true


  grunt.initConfig(config)

  grunt.registerTask 'compile', [
    'tslint',
    'ts',
    'dtsGenerator'
  ]

  grunt.registerTask 'watch-compile', [
    'tslint',
    'ts',
    'dtsGenerator'
  ]

  grunt.registerTask 'default', ['compile']

  return