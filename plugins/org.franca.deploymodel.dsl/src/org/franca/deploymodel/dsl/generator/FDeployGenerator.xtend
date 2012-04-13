/*******************************************************************************
* Copyright (c) 2012 Harman International (http://www.harman.com).
* All rights reserved. This program and the accompanying materials
* are made available under the terms of the Eclipse Public License v1.0
* which accompanies this distribution, and is available at
* http://www.eclipse.org/legal/epl-v10.html
*******************************************************************************/
package org.franca.deploymodel.dsl.generator

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IGenerator
import org.eclipse.xtext.generator.IFileSystemAccess
import org.franca.deploymodel.dsl.fDeploy.FDSpecification
import org.franca.deploymodel.dsl.fDeploy.FDTypeRef
import org.franca.deploymodel.dsl.fDeploy.FDPredefinedTypeId
import org.franca.deploymodel.dsl.fDeploy.FDEnumType
import org.franca.deploymodel.dsl.fDeploy.FDPropertyDecl
import org.franca.deploymodel.dsl.fDeploy.FDDeclaration
import org.franca.deploymodel.dsl.fDeploy.FDPropertyHost
import java.util.Set
import java.util.HashSet

/**
 * Generator for PropertyAccessor class from deployment specification.
 * The deployment specification is defined as fdepl model (spec part).
 * 
 * The accessor classes generated by this generator will be useful when
 * traversing a fidl model and getting the deployment properties for this
 * model.
 */
class FDeployGenerator implements IGenerator {
	
	// the types of PropertyAccessor classes we can generate
	static int PA_PROVIDER = 1
	static int PA_INTERFACE = 2
	
	// the main function for this generator, will be called by Xtend framework
	override void doGenerate(Resource resource, IFileSystemAccess fsa) {
		for(m : resource.allContents.toIterable.filter(typeof(FDSpecification))) {
			val path = m.getPackage().replace(".", "/")
			
			// generate PropertyAccessor for providers
			val ppa = m.generateAll(PA_PROVIDER)
			fsa.generateFile(path + "/" + m.classnameProvider + ".java", ppa)

			// generate PropertyAccessor for interfaces
			val ipa = m.generateAll(PA_INTERFACE)
			fsa.generateFile(path + "/" + m.classnameInterface + ".java", ipa)
		}
	}
	
	
	// *****************************************************************************
	// top-level generation and analysis
	
	int paType
	Set<String> neededFrancaTypes
	boolean needList
	boolean needArrayList
	
	def generateAll (FDSpecification spec, int pat) {
		// initialize
		paType = pat;
		neededFrancaTypes = new HashSet<String>()
		needList = false
		needArrayList = false
		
		// generate class code and analyse for needed preliminaries
		val code = spec.generateClass.toString
		var header = spec.generateHeader.toString
		header + code
	}
	
	
	def generateHeader (FDSpecification spec) '''
		/*******************************************************************************
		* This file has been generated by Franca's FDeployGenerator.
		* Source: deployment spec '�spec.name�'
		*******************************************************************************/
		�IF ! spec.getPackage.empty�
		package �spec.getPackage�;
		
		�ENDIF�
		�IF needList�
		import java.util.List;
		import java.util.ArrayList;
		�ENDIF�
		�FOR t : neededFrancaTypes�
		�IF t.equals("EObject")�
		import org.eclipse.emf.ecore.EObject;
		�ELSEIF t.equals("FDProvider") || t.equals("FDInterfaceInstance")�
		import org.franca.deploymodel.dsl.fDeploy.�t�;
		�ELSE�
		import org.franca.core.franca.�t�;
		�ENDIF�
		�ENDFOR�
		import org.franca.deploymodel.core.�supportingClass�;
		
	'''


	// this function will also collect neededFrancaTypes
	def generateClass (FDSpecification spec) '''
		/**
		 * Accessor for deployment properties for '�spec.name�' specification
		 */		
		public class �spec.classname�
			�IF spec.base!=null�extends �spec.base.getPackage�.�spec.base.classname��ENDIF�
		{
			
			private �supportingClass� target;
		
			public �spec.classname� (�supportingClass� target) {
				�IF spec.base!=null�
				super(target);
				�ENDIF�
				this.target = target;
			}
			
			�FOR d : spec.declarations�
			�d.genProperties�
			�ENDFOR�
			
		}
	'''


	// *****************************************************************************
	// property generation

	def genProperties (FDDeclaration decl) '''
		�FOR p : decl.properties�
		�p.genProperty(decl.host)�
		�ENDFOR�
	'''
	
	def genProperty (FDPropertyDecl it, FDPropertyHost host) {
		if (paType==PA_PROVIDER) {
			switch (host) {
				case FDPropertyHost::PROVIDERS:     genGetter("FDProvider")
				case FDPropertyHost::INSTANCES:     genGetter("FDInterfaceInstance")
				default: ""  // ignore all other hosts
			}
		} else {
			switch (host) {
				case FDPropertyHost::PROVIDERS:     ""  // ignore
				case FDPropertyHost::INSTANCES:     ""  // ignore
				case FDPropertyHost::INTERFACES:    genGetter("FInterface")
				case FDPropertyHost::ATTRIBUTES:    genGetter("FAttribute")
				case FDPropertyHost::METHODS:       genGetter("FMethod")
				case FDPropertyHost::BROADCASTS:    genGetter("FBroadcast")
				case FDPropertyHost::ARGUMENTS:     genGetter("FArgument")
				//case FDPropertyHost::NUMBERS:       genGetter("FArgument")
				//case FDPropertyHost::FLOATS:        genGetter("FArgument")
				//case FDPropertyHost::INTEGERS:      genGetter("FArgument")
				//case FDPropertyHost::STRINGS:       genGetter("FArgument")
				case FDPropertyHost::STRUCT_FIELDS: genGetter("FMethod")
				//case FDPropertyHost::ARRAYS:        genGetter("FArgument")
				default: genGetter("EObject")  // reasonable default
			}
		}
	}	
	

	def genGetter (FDPropertyDecl it, String fType) {
		neededFrancaTypes.add(fType)
		if (type.complex!=null) {
			val ct = type.complex			
			switch (ct) {
				FDEnumType: genEnumGetter(ct, fType)
				default:    genDefaultGetter(fType)
			}
		} else {
			genDefaultGetter(fType)
		}
	}

	def genDefaultGetter (FDPropertyDecl it, String fType) '''
		public �type.javaType� get�name.toFirstUpper� (�fType� obj) {
			return target.get�type.getter�(obj, "�name�");
		}

	'''
	
	def genEnumGetter (FDPropertyDecl it, FDEnumType enumerator, String fType) {
		neededFrancaTypes.add(fType)
		val etname = name.toFirstUpper
		val lname =
			if (type.array==null) {
				etname
			} else {
				needArrayList = true;
				etname.genListType
			}
		
		'''
			public enum �etname� {
				�FOR e : enumerator.enumerators SEPARATOR ", "��e.name��ENDFOR�
			}
			public �lname� get�name.toFirstUpper� (�fType� obj) {
				�type.javaType� e = target.get�type.getter�(obj, "�etname�");
				�IF it.type.array!=null�
				List<�etname�> es = new ArrayList<�etname�>();
				for(String ev : e) {
					�etname� v = convert�etname�(ev);
					if (v==null) {
						return null;
					} else {
						es.add(v);
					}
				}
				return es;
				�ELSE�
				return convert�etname�(e);
				�ENDIF�
			}
			private �etname� convert�etname� (String val) {
				�FOR e : enumerator.enumerators SEPARATOR " else "�
				if (val.equals("�e.name�"))
					return �etname�.�e.name�;
				�ENDFOR�
				return null;
			}
			
		'''
	}

		
	// *****************************************************************************
	// type-related generation
	
	def getJavaType (FDTypeRef typeRef) {
		val single =
			if (typeRef.complex==null) {
				switch (typeRef.predefined) {
					case FDPredefinedTypeId::BOOLEAN: "Boolean"
					case FDPredefinedTypeId::INTEGER: "Integer"
					case FDPredefinedTypeId::STRING:  "String"
				}
			} else {
				val ct = typeRef.complex
				switch (ct) {
					FDEnumType: "String"
				}
			}
		if (typeRef.array==null)
			single
		else {
			needList = true;			
			single.genListType
		}
	}
	
	def getGetter (FDTypeRef typeRef) {
		val single =
			if (typeRef.complex==null) {
				switch (typeRef.predefined) {
					case FDPredefinedTypeId::BOOLEAN: "Boolean"
					case FDPredefinedTypeId::INTEGER: "Integer"
					case FDPredefinedTypeId::STRING:  "String"
				}
			} else {
				switch (typeRef.complex) {
					FDEnumType: "Enum"
				}
			}
		if (typeRef.array==null)
			single
		else
			single + "Array"
	}


	// *****************************************************************************
	// basic helpers

	def genListType (String type) '''List<�type�>'''
		
	def getPackage (FDSpecification it) {
		val sep = name.lastIndexOf(".")
		if (sep>0)
			name.substring(0, sep)
		else
			""
	}

	def getClassname (FDSpecification it) {
		if (paType==PA_PROVIDER)
			classnameProvider
		else
			classnameInterface
	}

	def getClassnameProvider (FDSpecification it) {
		getClassnameGeneric("Provider")
	}

	def getClassnameInterface (FDSpecification it) {
		getClassnameGeneric("Interface")
	}

	def getClassnameGeneric (FDSpecification it, String type) {
		val sep = name.lastIndexOf(".")
		val basename = if (sep>0) name.substring(sep+1) else name
		basename.toFirstUpper + type + "PropertyAccessor"
	}

	def getSupportingClass() {
		if (paType==PA_PROVIDER)
			"FDeployedProvider"
		else
			"FDeployedInterface"
	}
}
